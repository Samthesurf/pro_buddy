"""
Goal Journey API Router.

Endpoints for managing goal journeys, steps, and AI-powered adjustments.
"""

from datetime import datetime
from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, Request
import uuid

from ..dependencies import get_current_user
from ..models.goal_journey import (
    GoalJourney,
    GoalStep,
    StepStatus,
    JourneyGenerateRequest,
    JourneyGenerateResponse,
    JourneyAdjustmentRequest,
    JourneyAdjustmentResponse,
    StepStatusUpdate,
    StepTitleUpdate,
    StepNoteAdd,
)
from ..services.journey_generator import get_journey_generator

router = APIRouter()

# In-memory storage for development (will be replaced with D1)
_journeys_store: dict[str, GoalJourney] = {}
_steps_store: dict[str, GoalStep] = {}


def _get_user_journey(user_id: str) -> Optional[GoalJourney]:
    """Get the user's active journey from storage."""
    for journey in _journeys_store.values():
        if journey.user_id == user_id:
            return journey
    return None


def _save_journey(journey: GoalJourney) -> None:
    """Save a journey to storage."""
    _journeys_store[journey.id] = journey
    for step in journey.steps:
        _steps_store[step.id] = step


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
    user_id: str = Depends(get_current_user),
):
    """
    Generate a new journey from a goal.
    
    This creates an AI-powered step-by-step journey to achieve the goal.
    """
    generator = get_journey_generator()
    
    journey = await generator.generate_journey(
        user_id=user_id,
        goal_content=request.goal_content,
        goal_reason=request.goal_reason,
        goal_id=request.goal_id,
        identity=request.identity,
        challenges=request.challenges,
    )
    
    _save_journey(journey)
    
    return JourneyGenerateResponse(
        journey=journey,
        ai_message=journey.ai_notes or "Your journey has been created! Let's get started.",
    )


@router.get("", response_model=Optional[GoalJourney])
async def get_current_journey(
    user_id: str = Depends(get_current_user),
):
    """Get the user's current active journey."""
    journey = _get_user_journey(user_id)
    return journey


@router.get("/{journey_id}", response_model=GoalJourney)
async def get_journey(
    journey_id: str,
    user_id: str = Depends(get_current_user),
):
    """Get a specific journey by ID."""
    journey = _journeys_store.get(journey_id)
    
    if not journey:
        raise HTTPException(status_code=404, detail="Journey not found")
    
    if journey.user_id != user_id:
        raise HTTPException(status_code=403, detail="Not authorized to view this journey")
    
    return journey


@router.delete("/{journey_id}")
async def delete_journey(
    journey_id: str,
    user_id: str = Depends(get_current_user),
):
    """Delete a journey."""
    journey = _journeys_store.get(journey_id)
    
    if not journey:
        raise HTTPException(status_code=404, detail="Journey not found")
    
    if journey.user_id != user_id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this journey")
    
    # Remove journey and its steps
    del _journeys_store[journey_id]
    for step in journey.steps:
        if step.id in _steps_store:
            del _steps_store[step.id]
    
    return {"success": True, "message": "Journey deleted"}


# ─────────────────────────────────────────────────
# Step Management Endpoints
# ─────────────────────────────────────────────────

@router.put("/steps/{step_id}/status")
async def update_step_status(
    step_id: str,
    update: StepStatusUpdate,
    user_id: str = Depends(get_current_user),
):
    """
    Update the status of a step.
    
    When a step is completed, the next step becomes available.
    """
    step = _steps_store.get(step_id)
    if not step:
        raise HTTPException(status_code=404, detail="Step not found")
    
    journey = _journeys_store.get(step.journey_id)
    if not journey or journey.user_id != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")
    
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
    _steps_store[step_id] = updated_step
    
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
                    _steps_store[next_step.id] = updated_next
                break
    
    # Update journey
    updated_journey = GoalJourney(
        **{**journey.model_dump(), "steps": updated_steps}
    )
    updated_journey = _update_journey_progress(updated_journey)
    _save_journey(updated_journey)
    
    return {
        "success": True,
        "step": updated_step,
        "journey_progress": updated_journey.overall_progress,
    }


@router.put("/steps/{step_id}/title")
async def update_step_title(
    step_id: str,
    update: StepTitleUpdate,
    user_id: str = Depends(get_current_user),
):
    """Update the custom title of a step."""
    step = _steps_store.get(step_id)
    if not step:
        raise HTTPException(status_code=404, detail="Step not found")
    
    journey = _journeys_store.get(step.journey_id)
    if not journey or journey.user_id != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    updated_step = GoalStep(
        **{**step.model_dump(), "custom_title": update.custom_title}
    )
    _steps_store[step_id] = updated_step
    
    # Update journey
    updated_steps = [
        updated_step if s.id == step_id else s
        for s in journey.steps
    ]
    updated_journey = GoalJourney(
        **{**journey.model_dump(), "steps": updated_steps, "updated_at": datetime.utcnow()}
    )
    _save_journey(updated_journey)
    
    return {"success": True, "step": updated_step}


@router.post("/steps/{step_id}/notes")
async def add_step_note(
    step_id: str,
    note_request: StepNoteAdd,
    user_id: str = Depends(get_current_user),
):
    """Add a note to a step."""
    step = _steps_store.get(step_id)
    if not step:
        raise HTTPException(status_code=404, detail="Step not found")
    
    journey = _journeys_store.get(step.journey_id)
    if not journey or journey.user_id != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    updated_notes = step.notes + [note_request.note]
    updated_step = GoalStep(
        **{**step.model_dump(), "notes": updated_notes}
    )
    _steps_store[step_id] = updated_step
    
    # Update journey
    updated_steps = [
        updated_step if s.id == step_id else s
        for s in journey.steps
    ]
    updated_journey = GoalJourney(
        **{**journey.model_dump(), "steps": updated_steps, "updated_at": datetime.utcnow()}
    )
    _save_journey(updated_journey)
    
    return {"success": True, "step": updated_step}


# ─────────────────────────────────────────────────
# AI-Powered Adjustments
# ─────────────────────────────────────────────────

@router.post("/adjust", response_model=JourneyAdjustmentResponse)
async def adjust_journey(
    request: JourneyAdjustmentRequest,
    user_id: str = Depends(get_current_user),
):
    """
    Adjust the journey based on user's current activity.
    
    The AI analyzes what the user is doing and suggests path adjustments.
    """
    journey = _journeys_store.get(request.journey_id)
    
    if not journey:
        raise HTTPException(status_code=404, detail="Journey not found")
    
    if journey.user_id != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    generator = get_journey_generator()
    
    result = await generator.adjust_journey(
        journey=journey,
        current_activity=request.current_activity,
        additional_context=request.additional_context,
    )
    
    updated_journey = result["journey"]
    _save_journey(updated_journey)
    
    return JourneyAdjustmentResponse(
        journey=updated_journey,
        changes_made=result["changes_made"],
        ai_message=result["ai_message"],
    )


@router.post("/{journey_id}/recalculate")
async def recalculate_journey(
    journey_id: str,
    user_id: str = Depends(get_current_user),
):
    """
    Recalculate journey progress based on current step statuses.
    
    Useful after manual edits or syncing with daily progress.
    """
    journey = _journeys_store.get(journey_id)
    
    if not journey:
        raise HTTPException(status_code=404, detail="Journey not found")
    
    if journey.user_id != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    updated_journey = _update_journey_progress(journey)
    _save_journey(updated_journey)
    
    return {
        "success": True,
        "journey": updated_journey,
    }
