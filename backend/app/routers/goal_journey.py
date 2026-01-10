"""
Goal Journey API Router.

Endpoints for managing goal journeys, steps, and AI-powered adjustments.
"""

from datetime import datetime
from typing import Optional
from fastapi import APIRouter, HTTPException, Depends

from ..dependencies import get_current_user
from ..models.goal_journey import (
    GoalJourney,
    GoalStep,
    StepStatus,
    PathType,
    JourneyGenerateRequest,
    JourneyGenerateResponse,
    JourneyAdjustmentRequest,
    JourneyAdjustmentResponse,
    StepStatusUpdate,
    StepTitleUpdate,
    StepNoteAdd,
    StepChoosePath,
)
from ..services.journey_generator import get_journey_generator
from ..services.usage_store_service import usage_store_service

router = APIRouter()

def _require_journey_store_configured() -> None:
    """
    Ensure the persistent journey store is configured.

    Goal Journeys must be persisted (D1 via Worker) so progress survives backend restarts.
    """
    if not usage_store_service.configured:
        raise HTTPException(
            status_code=503,
            detail="Goal Journey storage is not configured",
        )


async def _load_current_journey(*, user_id: str) -> Optional[GoalJourney]:
    _require_journey_store_configured()
    data = await usage_store_service.get_current_goal_journey(user_id=user_id)
    if not data:
        return None
    return GoalJourney.model_validate(data)


async def _load_journey(*, user_id: str, journey_id: str) -> GoalJourney:
    _require_journey_store_configured()
    data = await usage_store_service.get_goal_journey(user_id=user_id, journey_id=journey_id)
    if not data:
        raise HTTPException(status_code=404, detail="Journey not found")
    return GoalJourney.model_validate(data)


async def _load_journey_by_step(*, user_id: str, step_id: str) -> GoalJourney:
    _require_journey_store_configured()
    data = await usage_store_service.get_goal_journey_by_step(user_id=user_id, step_id=step_id)
    if not data:
        raise HTTPException(status_code=404, detail="Step not found")
    return GoalJourney.model_validate(data)


async def _persist_journey(journey: GoalJourney) -> None:
    _require_journey_store_configured()
    await usage_store_service.upsert_goal_journey(journey=journey)


def _update_journey_progress(journey: GoalJourney) -> GoalJourney:
    """Recalculate journey progress based on step statuses."""
    main_steps = [s for s in journey.steps if s.is_on_main_path]
    if not main_steps:
        return journey
    
    completed = sum(1 for s in main_steps if s.status == StepStatus.COMPLETED)
    progress = completed / len(main_steps)
    
    # Find current step index
    current_index = 0
    for i, step in enumerate(sorted(main_steps, key=lambda s: s.order_index)):
        if step.status == StepStatus.IN_PROGRESS:
            current_index = i
            break
        elif step.status == StepStatus.AVAILABLE:
            current_index = i
            break
        elif step.status == StepStatus.COMPLETED:
            current_index = i + 1
    
    return GoalJourney(
        **{
            **journey.model_dump(),
            "overall_progress": progress,
            "current_step_index": min(current_index, len(main_steps) - 1),
            "updated_at": datetime.utcnow(),
        }
    )


# ─────────────────────────────────────────────────
# Journey Endpoints
# ─────────────────────────────────────────────────

@router.post("/generate", response_model=JourneyGenerateResponse)
async def generate_journey(
    request: JourneyGenerateRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Generate a new journey from a goal.
    
    This creates an AI-powered step-by-step journey to achieve the goal.
    """
    try:
        user_id = current_user["uid"]
        generator = get_journey_generator()
        
        journey = await generator.generate_journey(
            user_id=user_id,
            goal_content=request.goal_content,
            goal_reason=request.goal_reason,
            goal_id=request.goal_id,
            identity=request.identity,
            challenges=request.challenges,
        )

        await _persist_journey(journey)
        
        return JourneyGenerateResponse(
            journey=journey,
            ai_message=journey.ai_notes or "Your journey has been created! Let's get started.",
        )
    except Exception as e:
        print(f"[goal_journey] Error in generate_journey endpoint: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to generate journey: {str(e)}")


@router.get("", response_model=Optional[GoalJourney])
async def get_current_journey(
    current_user: dict = Depends(get_current_user),
):
    """Get the user's current active journey."""
    user_id = current_user["uid"]
    return await _load_current_journey(user_id=user_id)


@router.get("/{journey_id}", response_model=GoalJourney)
async def get_journey(
    journey_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Get a specific journey by ID."""
    user_id = current_user["uid"]
    return await _load_journey(user_id=user_id, journey_id=journey_id)


@router.delete("/{journey_id}")
async def delete_journey(
    journey_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Delete a journey."""
    user_id = current_user["uid"]

    # Validate ownership/existence (returns 404 if missing/not owned).
    await _load_journey(user_id=user_id, journey_id=journey_id)

    await usage_store_service.delete_goal_journey(user_id=user_id, journey_id=journey_id)
    return {"success": True, "message": "Journey deleted"}


# ─────────────────────────────────────────────────
# Step Management Endpoints
# ─────────────────────────────────────────────────

@router.put("/steps/{step_id}/status")
async def update_step_status(
    step_id: str,
    update: StepStatusUpdate,
    current_user: dict = Depends(get_current_user),
):
    """
    Update the status of a step.
    
    When a step is completed, the next step becomes available.
    """
    user_id = current_user["uid"]

    journey = await _load_journey_by_step(user_id=user_id, step_id=step_id)
    step = next((s for s in journey.steps if s.id == step_id), None)
    if not step:
        raise HTTPException(status_code=404, detail="Step not found")

    now = datetime.utcnow()
    
    # Calculate actual days spent if completing
    actual_days = None
    if update.status == StepStatus.COMPLETED and step.started_at:
        actual_days = (now - step.started_at).days or 1
    
    # Update the step
    updated_step = GoalStep(
        **{
            **step.model_dump(),
            "status": update.status,
            "started_at": step.started_at or (now if update.status == StepStatus.IN_PROGRESS else None),
            "completed_at": now if update.status == StepStatus.COMPLETED else step.completed_at,
            "actual_days_spent": actual_days or step.actual_days_spent,
            "notes": step.notes + ([update.notes] if update.notes else []),
        }
    )
    
    # Update journey steps list
    updated_steps = [
        updated_step if s.id == step_id else s
        for s in journey.steps
    ]
    
    # If step completed, unlock next main path step
    if update.status == StepStatus.COMPLETED:
        main_steps = sorted(
            [s for s in updated_steps if s.is_on_main_path],
            key=lambda s: s.order_index
        )
        for i, s in enumerate(main_steps):
            if s.id == step_id and i + 1 < len(main_steps):
                next_step = main_steps[i + 1]
                if next_step.status == StepStatus.LOCKED:
                    updated_next = GoalStep(
                        **{**next_step.model_dump(), "status": StepStatus.AVAILABLE}
                    )
                    updated_steps = [
                        updated_next if s.id == next_step.id else s
                        for s in updated_steps
                    ]
                break
    
    # Update journey
    updated_journey = GoalJourney(
        **{**journey.model_dump(), "steps": updated_steps}
    )
    updated_journey = _update_journey_progress(updated_journey)
    await _persist_journey(updated_journey)
    
    return {
        "success": True,
        "step": updated_step,
        "journey_progress": updated_journey.overall_progress,
    }


@router.put("/steps/{step_id}/title")
async def update_step_title(
    step_id: str,
    update: StepTitleUpdate,
    current_user: dict = Depends(get_current_user),
):
    """Update the custom title of a step."""
    user_id = current_user["uid"]

    journey = await _load_journey_by_step(user_id=user_id, step_id=step_id)
    step = next((s for s in journey.steps if s.id == step_id), None)
    if not step:
        raise HTTPException(status_code=404, detail="Step not found")
    
    updated_step = GoalStep(
        **{**step.model_dump(), "custom_title": update.custom_title}
    )
    
    # Update journey
    updated_steps = [
        updated_step if s.id == step_id else s
        for s in journey.steps
    ]
    updated_journey = GoalJourney(
        **{**journey.model_dump(), "steps": updated_steps, "updated_at": datetime.utcnow()}
    )
    await _persist_journey(updated_journey)
    
    return {"success": True, "step": updated_step}


@router.post("/steps/{step_id}/notes")
async def add_step_note(
    step_id: str,
    note_request: StepNoteAdd,
    current_user: dict = Depends(get_current_user),
):
    """Add a note to a step."""
    user_id = current_user["uid"]

    journey = await _load_journey_by_step(user_id=user_id, step_id=step_id)
    step = next((s for s in journey.steps if s.id == step_id), None)
    if not step:
        raise HTTPException(status_code=404, detail="Step not found")
    
    updated_notes = step.notes + [note_request.note]
    updated_step = GoalStep(
        **{**step.model_dump(), "notes": updated_notes}
    )
    
    # Update journey
    updated_steps = [
        updated_step if s.id == step_id else s
        for s in journey.steps
    ]
    updated_journey = GoalJourney(
        **{**journey.model_dump(), "steps": updated_steps, "updated_at": datetime.utcnow()}
    )
    await _persist_journey(updated_journey)
    
    return {"success": True, "step": updated_step}


@router.post("/steps/{step_id}/choose-path", response_model=GoalJourney)
async def choose_path(
    step_id: str,
    request: StepChoosePath,
    current_user: dict = Depends(get_current_user),
):
    """
    Choose a path (branch) at a decision step.

    This updates path_type/status for the branch steps so the user's journey map
    adapts to the selected option.
    """
    user_id = current_user["uid"]

    journey = await _load_journey_by_step(user_id=user_id, step_id=step_id)

    steps = list(journey.steps)
    step_by_id = {s.id: s for s in steps}
    if step_id not in step_by_id:
        raise HTTPException(status_code=404, detail="Step not found in journey")

    decision = step_by_id[step_id]

    chosen_step_id = request.chosen_step_id
    chosen_step = step_by_id.get(chosen_step_id)
    if not chosen_step:
        raise HTTPException(status_code=404, detail="Chosen step not found")
    if chosen_step.journey_id != journey.id:
        raise HTTPException(
            status_code=400,
            detail="Chosen step must belong to the same journey",
        )

    # Build adjacency: prereq_id -> [child_step_ids]
    children_map: dict[str, list[str]] = {s.id: [] for s in steps}
    for s in steps:
        for prereq_id in s.prerequisites:
            if prereq_id in children_map:
                children_map[prereq_id].append(s.id)

    # Determine option roots. Prefer explicit "alternatives" if present.
    option_root_ids = list(decision.alternatives) if decision.alternatives else []
    if not option_root_ids:
        option_root_ids = children_map.get(decision.id, [])

    # Clean + dedupe, preserve order.
    cleaned: list[str] = []
    seen: set[str] = set()
    for opt_id in option_root_ids:
        if opt_id == decision.id:
            continue
        if opt_id not in step_by_id:
            continue
        if opt_id in seen:
            continue
        cleaned.append(opt_id)
        seen.add(opt_id)
    option_root_ids = cleaned

    if len(option_root_ids) < 2:
        raise HTTPException(
            status_code=400,
            detail="This step does not have multiple paths to choose from",
        )

    if chosen_step_id not in option_root_ids:
        raise HTTPException(
            status_code=400,
            detail="Chosen step is not a valid option for this decision point",
        )

    def collect_reachable(start_id: str) -> set[str]:
        visited: set[str] = set()
        stack: list[str] = [start_id]
        while stack:
            current = stack.pop()
            if current in visited:
                continue
            visited.add(current)
            for child_id in children_map.get(current, []):
                stack.append(child_id)
        return visited

    branch_ids_by_option = {
        opt_id: collect_reachable(opt_id) for opt_id in option_root_ids
    }
    affected_ids: set[str] = set()
    for ids in branch_ids_by_option.values():
        affected_ids |= ids

    # Prevent switching after the user has started any branch step.
    for sid in affected_ids:
        st = step_by_id[sid]
        if st.status in (StepStatus.IN_PROGRESS, StepStatus.COMPLETED):
            raise HTTPException(
                status_code=400,
                detail="You can't change paths after starting one. Use 'Adjust Journey' instead.",
            )

    updated_steps: list[GoalStep] = []
    for s in steps:
        if s.id not in affected_ids:
            updated_steps.append(s)
            continue

        in_chosen_branch = s.id in branch_ids_by_option[chosen_step_id]

        if in_chosen_branch:
            new_path_type = PathType.MAIN
            new_status = s.status
            if new_status == StepStatus.ALTERNATIVE:
                new_status = StepStatus.LOCKED
        else:
            new_path_type = PathType.ALTERNATIVE
            # Mark as "alternative path not taken" unless it's already completed/in progress (blocked above).
            new_status = StepStatus.ALTERNATIVE

        updated_steps.append(
            GoalStep(
                **{
                    **s.model_dump(),
                    "path_type": new_path_type,
                    "status": new_status,
                }
            )
        )

    # Record the selected option on the decision step metadata for easy UI highlighting.
    updated_steps2: list[GoalStep] = []
    for s in updated_steps:
        if s.id != decision.id:
            updated_steps2.append(s)
            continue
        md = dict(s.metadata or {})
        md["selected_path_step_id"] = chosen_step_id
        updated_steps2.append(GoalStep(**{**s.model_dump(), "metadata": md}))

    # If the decision step is already completed, unlock the chosen root immediately.
    if decision.status == StepStatus.COMPLETED:
        updated_steps2 = [
            GoalStep(**{**s.model_dump(), "status": StepStatus.AVAILABLE})
            if s.id == chosen_step_id
            and s.status in (StepStatus.LOCKED, StepStatus.ALTERNATIVE)
            else s
            for s in updated_steps2
        ]

    updated_journey = GoalJourney(
        **{
            **journey.model_dump(),
            "steps": updated_steps2,
            "updated_at": datetime.utcnow(),
        }
    )
    updated_journey = _update_journey_progress(updated_journey)
    await _persist_journey(updated_journey)

    return updated_journey


# ─────────────────────────────────────────────────
# AI-Powered Adjustments
# ─────────────────────────────────────────────────

@router.post("/adjust", response_model=JourneyAdjustmentResponse)
async def adjust_journey(
    request: JourneyAdjustmentRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Adjust the journey based on user's current activity.
    
    The AI analyzes what the user is doing and suggests path adjustments.
    """
    user_id = current_user["uid"]

    journey = await _load_journey(user_id=user_id, journey_id=request.journey_id)
    generator = get_journey_generator()
    
    result = await generator.adjust_journey(
        journey=journey,
        current_activity=request.current_activity,
        additional_context=request.additional_context,
    )
    
    updated_journey = result["journey"]
    await _persist_journey(updated_journey)
    
    return JourneyAdjustmentResponse(
        journey=updated_journey,
        changes_made=result["changes_made"],
        ai_message=result["ai_message"],
    )


@router.post("/{journey_id}/recalculate")
async def recalculate_journey(
    journey_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Recalculate journey progress based on current step statuses.
    
    Useful after manual edits or syncing with daily progress.
    """
    user_id = current_user["uid"]

    journey = await _load_journey(user_id=user_id, journey_id=journey_id)
    updated_journey = _update_journey_progress(journey)
    await _persist_journey(updated_journey)
    
    return {
        "success": True,
        "journey": updated_journey,
    }
