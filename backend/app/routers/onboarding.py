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


router = APIRouter()


# Simple in-memory storage (replace with database in production)
_goals_db: dict = {}
_app_selections_db: dict = {}


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

    # Store in Cloudflare Vectorize
    if req and hasattr(req.app.state, "vectorize"):
        vectorize = req.app.state.vectorize
        await vectorize.store_user_goal(
            user_id=uid,
            goal_id=goal.id,
            content=goal.content,
            reason=goal.reason,
        )

    # Generate summary with Gemini
    summary = None
    if req and hasattr(req.app.state, "gemini"):
        gemini = req.app.state.gemini
        goals_data = [{"content": g.content, "reason": g.reason} for g in _goals_db[uid]]
        summary = await gemini.generate_goals_summary(goals_data)

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

