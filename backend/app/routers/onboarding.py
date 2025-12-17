"""
Onboarding router.
Handles goal setting and app selection during onboarding.
"""

from typing import List
from uuid import uuid4
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from .auth import get_current_user
from ..models.goal import GoalCreate, Goal, GoalsProfile
from ..models.app_selection import AppSelectionCreate, AppSelection, AppSelectionsCreate
from ..models.goal_discovery import (
    GoalDiscoveryStartRequest,
    GoalDiscoveryMessageRequest,
    GoalDiscoveryResponse,
    NotificationProfile,
)


router = APIRouter()


# Simple in-memory storage (replace with database in production)
_goals_db: dict = {}
_app_selections_db: dict = {}
_notification_profile_db: dict = {}  # user_id -> latest profile dict (cache)


def _merge_notification_profile(existing: dict, update: dict) -> dict:
    """
    Merge Gemini-extracted updates into an existing notification profile.

    - Never overwrite existing fields with null/empty values.
    - Lists are unioned (unique).
    """
    if not update:
        return existing

    merged = dict(existing or {})

    def set_if_present(key: str):
        val = update.get(key)
        if val is None:
            return
        if isinstance(val, str) and not val.strip():
            return
        merged[key] = val

    def merge_list(key: str):
        val = update.get(key)
        if not isinstance(val, list) or len(val) == 0:
            return
        existing_list = merged.get(key) or []
        if not isinstance(existing_list, list):
            existing_list = []
        # Keep order: existing first, then new uniques
        seen = {str(x).strip().lower() for x in existing_list if str(x).strip()}
        out = list(existing_list)
        for item in val:
            s = str(item).strip()
            if not s:
                continue
            k = s.lower()
            if k in seen:
                continue
            out.append(s)
            seen.add(k)
        merged[key] = out

    for k in [
        "identity",
        "primary_goal",
        "why",
        "stakes",
        "style",
        "preferred_name_for_user",
        "preferred_name_for_assistant",
        "app_intent_notes",
    ]:
        set_if_present(k)

    # Importance is numeric
    importance = update.get("importance_1_to_5")
    if isinstance(importance, int) and 1 <= importance <= 5:
        merged["importance_1_to_5"] = importance

    merge_list("motivators")
    merge_list("helpful_apps")
    merge_list("risky_apps")

    return merged


class GoalCreateRequest(BaseModel):
    """Request for creating a goal."""

    content: str
    reason: str | None = None
    timeline: str | None = None


class GoalsResponse(BaseModel):
    """Response for goals operations."""

    goals: List[Goal]
    summary: str | None = None


class AppSelectionsResponse(BaseModel):
    """Response for app selections."""

    selections: List[AppSelection]
    count: int


class OnboardingCompleteResponse(BaseModel):
    """Response for completing onboarding."""

    success: bool
    message: str
    goals_summary: str | None = None


@router.post("/goals", response_model=GoalsResponse)
async def save_goals(
    request: GoalCreateRequest,
    current_user: dict = Depends(get_current_user),
    req: Request = None,
):
    """
    Save user's goals during onboarding.

    The goals will be stored in Cloudflare Vectorize for semantic retrieval
    during app usage monitoring.
    """
    uid = current_user["uid"]

    # Create goal object
    goal = Goal(
        id=str(uuid4()),
        user_id=uid,
        content=request.content,
        reason=request.reason,
        timeline=request.timeline,
        created_at=datetime.utcnow(),
    )

    # Store in memory
    if uid not in _goals_db:
        _goals_db[uid] = []
    _goals_db[uid].append(goal)

    # Store in Cloudflare Vectorize (optional for development)
    if req and hasattr(req.app.state, "vectorize"):
        try:
            vectorize = req.app.state.vectorize
            await vectorize.store_user_goal(
                user_id=uid,
                goal_id=goal.id,
                content=goal.content,
                reason=goal.reason,
            )
        except Exception as e:
            print(f"Warning: Failed to store goal in Vectorize: {e}")

    # Generate summary with Gemini (optional for development)
    summary = None
    if req and hasattr(req.app.state, "gemini"):
        try:
            gemini = req.app.state.gemini
            goals_data = [{"content": g.content, "reason": g.reason} for g in _goals_db[uid]]
            summary = await gemini.generate_goals_summary(goals_data)
        except Exception as e:
            print(f"Warning: Failed to generate summary with Gemini: {e}")

    return GoalsResponse(
        goals=_goals_db[uid],
        summary=summary,
    )


@router.get("/goals", response_model=GoalsResponse)
async def get_goals(
    current_user: dict = Depends(get_current_user),
):
    """Get user's saved goals."""
    uid = current_user["uid"]
    goals = _goals_db.get(uid, [])

    return GoalsResponse(goals=goals)


@router.post("/apps", response_model=AppSelectionsResponse)
async def save_app_selections(
    request: AppSelectionsCreate,
    current_user: dict = Depends(get_current_user),
    req: Request = None,
):
    """
    Save user's app selections during onboarding.

    Each app includes the user's reason for why it helps
    achieve their goals and an importance rating.
    """
    uid = current_user["uid"]

    selections = []
    for app_data in request.apps:
        selection = AppSelection(
            id=str(uuid4()),
            user_id=uid,
            package_name=app_data.package_name,
            app_name=app_data.app_name,
            reason=app_data.reason,
            importance_rating=app_data.importance_rating,
            created_at=datetime.utcnow(),
        )
        selections.append(selection)

        # Store in Cloudflare Vectorize
        if req and hasattr(req.app.state, "vectorize"):
            vectorize = req.app.state.vectorize
            await vectorize.store_app_selection(
                user_id=uid,
                selection_id=selection.id,
                app_name=selection.app_name,
                package_name=selection.package_name,
                reason=selection.reason,
                importance=selection.importance_rating,
            )

    # Store in memory
    if uid not in _app_selections_db:
        _app_selections_db[uid] = []
    _app_selections_db[uid].extend(selections)

    return AppSelectionsResponse(
        selections=_app_selections_db[uid],
        count=len(_app_selections_db[uid]),
    )


@router.get("/apps", response_model=AppSelectionsResponse)
async def get_app_selections(
    current_user: dict = Depends(get_current_user),
):
    """Get user's app selections."""
    uid = current_user["uid"]
    selections = _app_selections_db.get(uid, [])

    return AppSelectionsResponse(
        selections=selections,
        count=len(selections),
    )


@router.post("/complete", response_model=OnboardingCompleteResponse)
async def complete_onboarding(
    current_user: dict = Depends(get_current_user),
    req: Request = None,
):
    """
    Mark onboarding as complete.

    This triggers final processing of goals and app selections,
    including generating embeddings for semantic search.
    """
    uid = current_user["uid"]

    # Check if user has goals and apps
    goals = _goals_db.get(uid, [])
    apps = _app_selections_db.get(uid, [])

    if not goals:
        raise HTTPException(
            status_code=400,
            detail="Please set at least one goal before completing onboarding",
        )

    # Generate final summary
    summary = None
    if req and hasattr(req.app.state, "gemini"):
        gemini = req.app.state.gemini
        goals_data = [{"content": g.content, "reason": g.reason} for g in goals]
        summary = await gemini.generate_goals_summary(goals_data)

    # Mark user as onboarded (in a real app, update the database)
    # This is a placeholder - in production, update the user record

    return OnboardingCompleteResponse(
        success=True,
        message=f"Onboarding complete! You've set {len(goals)} goal(s) and selected {len(apps)} app(s).",
        goals_summary=summary,
    )


@router.post("/goal-discovery/start", response_model=GoalDiscoveryResponse)
async def start_goal_discovery(
    body: GoalDiscoveryStartRequest,
    current_user: dict = Depends(get_current_user),
    req: Request = None,
):
    """
    Start (or reset) a back-and-forth goal discovery conversation.

    This produces a structured "notification profile" stored in Vectorize (RAG),
    so future notifications can reference what the user said matters to them.
    """
    uid = current_user["uid"]
    session_id = str(uuid4())

    vectorize = req.app.state.vectorize if req and hasattr(req.app.state, "vectorize") else None
    gemini = req.app.state.gemini if req and hasattr(req.app.state, "gemini") else None

    existing_profile = None
    if vectorize and not body.reset:
        existing_profile = await vectorize.get_notification_profile(uid)

    if body.reset:
        existing_profile = {}
        _notification_profile_db[uid] = {}
    elif not existing_profile:
        existing_profile = _notification_profile_db.get(uid) or {}

    ai_message = "Let’s get clear on what you’re aiming for. What’s the goal that matters most to you right now?"
    done = False
    profile_dict = existing_profile

    if gemini:
        result = await gemini.goal_discovery_step(
            user_message=None,
            conversation_history=[],
            existing_profile=existing_profile,
        )
        ai_message = result.get("assistant_message", ai_message)
        done = bool(result.get("done", False))
        profile_dict = _merge_notification_profile(existing_profile, result.get("profile") or {})

    # Cache locally and store assistant message for RAG/history
    _notification_profile_db[uid] = profile_dict

    if vectorize:
        await vectorize.store_goal_discovery_message(
            user_id=uid,
            session_id=session_id,
            message_id=str(uuid4()),
            role="assistant",
            content=ai_message,
            timestamp=datetime.utcnow().isoformat(),
        )

    profile = None
    if profile_dict:
        # Ensure required fields for response model
        profile_kwargs = dict(profile_dict)
        # Vectorize retrieval may include user_id already; avoid double-passing it.
        profile_kwargs.pop("user_id", None)
        profile = NotificationProfile(user_id=uid, **profile_kwargs)

    return GoalDiscoveryResponse(
        session_id=session_id,
        message=ai_message,
        done=done,
        profile=profile,
    )


@router.post("/goal-discovery/message", response_model=GoalDiscoveryResponse)
async def goal_discovery_message(
    body: GoalDiscoveryMessageRequest,
    current_user: dict = Depends(get_current_user),
    req: Request = None,
):
    """
    Continue the goal-discovery conversation (one user message -> one AI reply).
    """
    uid = current_user["uid"]

    vectorize = req.app.state.vectorize if req and hasattr(req.app.state, "vectorize") else None
    gemini = req.app.state.gemini if req and hasattr(req.app.state, "gemini") else None

    existing_profile = None
    if vectorize:
        existing_profile = await vectorize.get_notification_profile(uid)
    if not existing_profile:
        existing_profile = _notification_profile_db.get(uid) or {}

    history = []
    if vectorize:
        history = await vectorize.get_goal_discovery_history(
            user_id=uid,
            session_id=body.session_id,
            n_results=30,
        )

    # Store user message in RAG/history
    if vectorize:
        await vectorize.store_goal_discovery_message(
            user_id=uid,
            session_id=body.session_id,
            message_id=str(uuid4()),
            role="user",
            content=body.message,
            timestamp=datetime.utcnow().isoformat(),
        )

    ai_message = "Thanks — tell me a bit more about why that matters to you."
    done = False
    updated_profile = existing_profile

    if gemini:
        result = await gemini.goal_discovery_step(
            user_message=body.message,
            conversation_history=history,
            existing_profile=existing_profile,
        )
        ai_message = result.get("assistant_message", ai_message)
        done = bool(result.get("done", False))
        updated_profile = _merge_notification_profile(
            existing_profile, result.get("profile") or {}
        )

    # Always stamp update time when we have any profile content
    if updated_profile is not None:
        updated_profile = dict(updated_profile)
        updated_profile["updated_at"] = datetime.utcnow()

    _notification_profile_db[uid] = updated_profile or {}

    # Persist profile into Vectorize for retrieval during notifications
    if vectorize and updated_profile:
        # Serialize datetimes safely
        to_store = dict(updated_profile)
        if isinstance(to_store.get("updated_at"), datetime):
            to_store["updated_at"] = to_store["updated_at"].isoformat()
        await vectorize.store_notification_profile(uid, to_store)

    # Store assistant message
    if vectorize:
        await vectorize.store_goal_discovery_message(
            user_id=uid,
            session_id=body.session_id,
            message_id=str(uuid4()),
            role="assistant",
            content=ai_message,
            timestamp=datetime.utcnow().isoformat(),
        )

    profile = None
    if updated_profile:
        # Ensure updated_at is a datetime for the response model
        profile_kwargs = dict(updated_profile)
        # Vectorize retrieval may include user_id already; avoid double-passing it.
        profile_kwargs.pop("user_id", None)
        if isinstance(profile_kwargs.get("updated_at"), str):
            try:
                profile_kwargs["updated_at"] = datetime.fromisoformat(
                    profile_kwargs["updated_at"]
                )
            except Exception:
                profile_kwargs["updated_at"] = datetime.utcnow()
        profile = NotificationProfile(user_id=uid, **profile_kwargs)

    return GoalDiscoveryResponse(
        session_id=body.session_id,
        message=ai_message,
        done=done,
        profile=profile,
    )


@router.get("/notification-profile")
async def get_notification_profile(
    current_user: dict = Depends(get_current_user),
    req: Request = None,
):
    """Fetch the user's latest stored notification profile (from Vectorize if available)."""
    uid = current_user["uid"]

    vectorize = req.app.state.vectorize if req and hasattr(req.app.state, "vectorize") else None
    profile = None
    if vectorize:
        profile = await vectorize.get_notification_profile(uid)
    if not profile:
        profile = _notification_profile_db.get(uid)
    return {"profile": profile or None}
