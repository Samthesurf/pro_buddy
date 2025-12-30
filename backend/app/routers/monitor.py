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
from ..config import settings
from ..models.usage import (
    AppUsageEvent,
    UsageFeedback,
    UsageFeedbackResponse,
    DailySummary,
    AlignmentStatus,
)
from ..services.usage_store_service import usage_store_service


router = APIRouter()


# Simple in-memory storage (fallback when D1 Worker isn't configured)
_usage_history_db: dict = {}
_last_notification_time: dict = {}  # Track notification cooldowns


def _personalize_notification_message(
    base_message: str,
    profile: dict,
    app_name: str,
    alignment: AlignmentStatus,
) -> str:
    """
    Lightweight personalization using the stored notification profile.

    This avoids an extra LLM call in the hot path.
    """
    if not profile:
        return base_message

    assistant_name = (profile.get("preferred_name_for_assistant") or "Hawk Buddy").strip()
    user_name = (profile.get("preferred_name_for_user") or "").strip()
    identity = (profile.get("identity") or "").strip()
    primary_goal = (profile.get("primary_goal") or "").strip()
    why = (profile.get("why") or "").strip()
    motivators = profile.get("motivators") or []
    importance = profile.get("importance_1_to_5")
    risky_apps = [str(x).strip().lower() for x in (profile.get("risky_apps") or [])]

    app_l = app_name.lower()
    is_youtube = "youtube" in app_l
    is_risky = any(r and r in app_l for r in risky_apps)

    # Only override when we're actually going to notify, and it's meaningful.
    if alignment == AlignmentStatus.MISALIGNED and (is_youtube or is_risky):
        name_prefix = f"Hey {user_name}," if user_name else "Hey,"
        identity_phrase = f" a bigger {identity}" if identity else ""
        goal_phrase = f" for {primary_goal}" if primary_goal else ""
        importance_phrase = (
            f" (you rated this {importance}/5)" if isinstance(importance, int) else ""
        )
        reason = ""
        if why:
            reason = f" Remember: {why}"
        elif motivators:
            reason = f" Remember: {motivators[0]}"

        return (
            f"{name_prefix} {assistant_name} here — is {app_name} helping you become{identity_phrase}{goal_phrase} right now{importance_phrase}?"
            f"{reason}"
        ).strip()

    # Gentle boost for aligned notifications too (keep short)
    if alignment == AlignmentStatus.ALIGNED and primary_goal:
        return f"{base_message} (Nice — this supports {primary_goal}.)"

    return base_message


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
    notification_profile: dict | None = None
    if req and hasattr(req.app.state, "vectorize"):
        vectorize = req.app.state.vectorize
        user_context = await vectorize.get_user_context(uid)
        notification_profile = await vectorize.get_notification_profile(uid)

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
    should_notify = False
    alignment_status: AlignmentStatus = feedback_data["alignment_status"]
    if usage_store_service.configured:
        # Persist cooldowns in D1 via Worker (no in-memory growth).
        try:
            if alignment_status == AlignmentStatus.ALIGNED:
                cooldown_seconds = int(settings.encouraging_cooldown_hours) * 60 * 60
            elif alignment_status == AlignmentStatus.MISALIGNED:
                cooldown_seconds = int(settings.reminder_cooldown_minutes) * 60
            else:
                cooldown_seconds = 2 * 60 * 60

            should_notify = await usage_store_service.check_and_set_cooldown(
                user_id=uid,
                package_name=request.package_name,
                alignment=alignment_status,
                cooldown_seconds=cooldown_seconds,
            )
        except Exception as e:
            # Fail closed to avoid notification spam when storage is down.
            print(f"Warning: failed to check cooldown via usage store worker: {e}")
            should_notify = False
    else:
        # Fallback: in-memory cooldowns (dev-only / when Worker not configured).
        should_notify = _should_send_notification(
            uid,
            request.package_name,
            alignment_status,
        )

    if should_notify and notification_profile:
        feedback_data["message"] = _personalize_notification_message(
            feedback_data.get("message") or "Keep going!",
            notification_profile,
            request.app_name,
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

    if usage_store_service.configured:
        # Persist history in D1 via Worker (no in-memory growth).
        try:
            await usage_store_service.store_usage_feedback(feedback)
        except Exception as e:
            print(f"Warning: failed to store usage feedback via usage store worker: {e}")
    else:
        # Store in history (in-memory fallback)
        if uid not in _usage_history_db:
            _usage_history_db[uid] = []
        _usage_history_db[uid].append(feedback)

        # Update last notification time if we're notifying
        if should_notify:
            key = f"{uid}_{request.package_name}_{alignment_status.value}"
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
    if usage_store_service.configured:
        try:
            items = await usage_store_service.get_usage_history(
                user_id=uid,
                start_date=start_date,
                end_date=end_date,
                limit=limit,
            )
            history = [UsageFeedback(**item) for item in items]
            return UsageHistoryResponse(items=history, total=len(history))
        except Exception as e:
            print(f"Warning: failed to read usage history via usage store worker: {e}")
            return UsageHistoryResponse(items=[], total=0)

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

    if usage_store_service.configured:
        try:
            items = await usage_store_service.get_usage_history(
                user_id=uid,
                start_date=day_start,
                end_date=day_end,  # inclusive in worker; we'll re-filter below
                limit=5000,
            )
            history = [UsageFeedback(**item) for item in items]
        except Exception as e:
            print(f"Warning: failed to read summary history via usage store worker: {e}")
            history = []
    else:
        history = _usage_history_db.get(uid, [])

    # Filter history for this day (keep end exclusive)
    day_history = [h for h in history if day_start <= h.created_at < day_end]

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
