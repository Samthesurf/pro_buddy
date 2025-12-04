"""
Monitoring router.
Handles app usage reporting and feedback.
"""

from typing import List, Optional
from uuid import uuid4
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, Request, Query
from pydantic import BaseModel

from .auth import get_current_user
from ..models.usage import (
    AppUsageEvent,
    UsageFeedback,
    UsageFeedbackResponse,
    DailySummary,
    AlignmentStatus,
)


router = APIRouter()


# Simple in-memory storage (replace with database in production)
_usage_history_db: dict = {}
_last_notification_time: dict = {}  # Track notification cooldowns


class AppUsageRequest(BaseModel):
    """Request for reporting app usage."""

    package_name: str
    app_name: str


class UsageHistoryResponse(BaseModel):
    """Response for usage history."""

    items: List[UsageFeedback]
    total: int


@router.post("/app-usage", response_model=UsageFeedbackResponse)
async def report_app_usage(
    request: AppUsageRequest,
    current_user: dict = Depends(get_current_user),
    req: Request = None,
):
    """
    Report app usage and get feedback.

    This endpoint is called when the monitoring service detects
    that the user has switched to a new app.
    """
    uid = current_user["uid"]

    # Get user context from Cloudflare Vectorize
    user_context = {"goals": [], "app_selections": []}
    if req and hasattr(req.app.state, "vectorize"):
        vectorize = req.app.state.vectorize
        user_context = await vectorize.get_user_context(uid)

    # Get or create app classification
    app_classification = None
    if req and hasattr(req.app.state, "vectorize"):
        app_classification = await req.app.state.vectorize.get_app_classification(
            request.package_name
        )

    # If not cached, classify with Gemini
    if not app_classification and req and hasattr(req.app.state, "gemini"):
        gemini = req.app.state.gemini
        classification = await gemini.classify_app(
            request.app_name,
            request.package_name,
        )

        # Store classification
        if req and hasattr(req.app.state, "vectorize"):
            await req.app.state.vectorize.store_app_classification(
                package_name=request.package_name,
                app_name=request.app_name,
                category=classification["category"],
                description=classification["description"],
                typical_uses=classification["typical_uses"],
            )

        app_classification = classification
    elif not app_classification:
        app_classification = {
            "category": "other",
            "description": request.app_name,
            "typical_uses": [],
        }

    # Analyze alignment with Gemini
    feedback_data = {
        "aligned": True,
        "alignment_status": AlignmentStatus.NEUTRAL,
        "message": "Keep going!",
        "reason": None,
    }

    if req and hasattr(req.app.state, "gemini"):
        gemini = req.app.state.gemini
        feedback_data = await gemini.analyze_alignment(
            app_name=request.app_name,
            app_classification=app_classification,
            user_goals=user_context.get("goals", []),
            user_apps=user_context.get("app_selections", []),
        )

    # Determine if we should send a notification (rate limiting)
    should_notify = _should_send_notification(
        uid,
        request.package_name,
        feedback_data["alignment_status"],
    )

    # Create feedback record
    feedback = UsageFeedback(
        id=str(uuid4()),
        user_id=uid,
        package_name=request.package_name,
        app_name=request.app_name,
        alignment=feedback_data["alignment_status"],
        message=feedback_data["message"],
        reason=feedback_data.get("reason"),
        created_at=datetime.utcnow(),
        notification_sent=should_notify,
    )

    # Store in history
    if uid not in _usage_history_db:
        _usage_history_db[uid] = []
    _usage_history_db[uid].append(feedback)

    # Update last notification time if we're notifying
    if should_notify:
        key = f"{uid}_{request.package_name}_{feedback_data['alignment_status'].value}"
        _last_notification_time[key] = datetime.utcnow()

    return UsageFeedbackResponse(
        aligned=feedback_data["aligned"],
        alignment_status=feedback_data["alignment_status"],
        message=feedback_data["message"],
        reason=feedback_data.get("reason"),
        should_notify=should_notify,
    )


@router.get("/history", response_model=UsageHistoryResponse)
async def get_usage_history(
    current_user: dict = Depends(get_current_user),
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    limit: int = Query(50, ge=1, le=500),
):
    """Get usage history with feedback."""
    uid = current_user["uid"]
    history = _usage_history_db.get(uid, [])

    # Filter by date range
    if start_date:
        history = [h for h in history if h.created_at >= start_date]
    if end_date:
        history = [h for h in history if h.created_at <= end_date]

    # Sort by most recent first
    history = sorted(history, key=lambda x: x.created_at, reverse=True)

    # Apply limit
    history = history[:limit]

    return UsageHistoryResponse(
        items=history,
        total=len(history),
    )


@router.get("/summary", response_model=DailySummary)
async def get_daily_summary(
    current_user: dict = Depends(get_current_user),
    date: Optional[datetime] = Query(None),
):
    """Get daily usage summary."""
    uid = current_user["uid"]
    target_date = date or datetime.utcnow()

    # Get today's start and end
    day_start = target_date.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start + timedelta(days=1)

    # Filter history for this day
    history = _usage_history_db.get(uid, [])
    day_history = [
        h for h in history if day_start <= h.created_at < day_end
    ]

    # Count by alignment
    aligned_count = sum(1 for h in day_history if h.alignment == AlignmentStatus.ALIGNED)
    neutral_count = sum(1 for h in day_history if h.alignment == AlignmentStatus.NEUTRAL)
    misaligned_count = sum(
        1 for h in day_history if h.alignment == AlignmentStatus.MISALIGNED
    )

    # Calculate alignment score (0-100)
    total = aligned_count + neutral_count + misaligned_count
    if total > 0:
        # Aligned = 100 points, Neutral = 50 points, Misaligned = 0 points
        score = ((aligned_count * 100) + (neutral_count * 50)) / total
    else:
        score = 100.0  # Default to perfect if no data

    return DailySummary(
        user_id=uid,
        date=target_date,
        aligned_count=aligned_count,
        neutral_count=neutral_count,
        misaligned_count=misaligned_count,
        total_aligned_time_ms=0,  # Would need duration tracking
        total_misaligned_time_ms=0,
        alignment_score=score,
        feedback_items=day_history,
    )


def _should_send_notification(
    user_id: str,
    package_name: str,
    alignment: AlignmentStatus,
) -> bool:
    """
    Determine if a notification should be sent based on cooldowns.

    Args:
        user_id: User ID
        package_name: App package name
        alignment: Alignment status

    Returns:
        True if notification should be sent
    """
    from ..config import settings

    key = f"{user_id}_{package_name}_{alignment.value}"
    last_time = _last_notification_time.get(key)

    if not last_time:
        return True

    now = datetime.utcnow()

    if alignment == AlignmentStatus.ALIGNED:
        cooldown = timedelta(hours=settings.encouraging_cooldown_hours)
    elif alignment == AlignmentStatus.MISALIGNED:
        cooldown = timedelta(minutes=settings.reminder_cooldown_minutes)
    else:
        # Neutral - less frequent notifications
        cooldown = timedelta(hours=2)

    return (now - last_time) > cooldown

