"""
Onboarding router.
Handles goal setting and app selection during onboarding.
"""

from typing import List
from uuid import uuid4
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Request, BackgroundTasks
from pydantic import BaseModel

from .auth import get_current_user, update_onboarding_status
from ..models.goal import GoalCreate, Goal, GoalsProfile
from ..models.app_selection import AppSelectionCreate, AppSelection, AppSelectionsCreate
from ..models.goal_discovery import (
    GoalDiscoveryStartRequest,
    GoalDiscoveryMessageRequest,
    GoalDiscoveryResponse,
    NotificationProfile,
)
from ..services.usage_store_service import usage_store_service


router = APIRouter()


# Simple in-memory storage (replace with database in production)
_goals_db: dict = {}  # user_id -> list of Goal (actual primary goals from Goal Discovery)
_app_selections_db: dict = {}
_notification_profile_db: dict = {}  # user_id -> latest profile dict (cache)
_goal_discovery_sessions: dict = {}  # session_id -> session state (in-memory)
_onboarding_preferences_db: dict = {}  # user_id -> onboarding preferences (challenges, habits, etc.)

# Goal discovery guardrails (kept intentionally small: this is onboarding UX).
_GOAL_DISCOVERY_MAX_USER_TURNS = 8
_GOAL_DISCOVERY_MAX_ASKS_PER_FIELD = 2


def _is_nonempty_str(value) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _is_goal_discovery_exit_intent(message: str) -> bool:
    """
    Detect explicit user intent to stop/skip the goal discovery flow.

    Keep this conservative so we don't misfire on normal sentences like
    "I need to be done by Friday".
    """
    if not isinstance(message, str):
        return False
    text = message.strip().lower()
    if not text:
        return False

    # Only treat very short messages as commands.
    if len(text) > 24:
        return False

    commands = {
        "exit",
        "quit",
        "stop",
        "cancel",
        "skip",
        "skip for now",
        "done",
        "im done",
        "i'm done",
        "thats it",
        "that's it",
        "finished",
        "end",
        "end chat",
    }
    return text in commands


def _is_profile_min_complete(profile: dict) -> bool:
    """
    "Good enough" profile to personalize notifications and proceed to app selection.

    Keep this minimal and deterministic so onboarding doesn't get stuck if the model
    fails to set done=true.
    """
    if not isinstance(profile, dict):
        return False

    importance = profile.get("importance_1_to_5")
    motivators = profile.get("motivators") or []
    stakes = profile.get("stakes")
    style = profile.get("style")

    has_motivation_signal = (
        isinstance(motivators, list) and len([m for m in motivators if str(m).strip()]) > 0
    ) or _is_nonempty_str(stakes)

    return (
        _is_nonempty_str(profile.get("primary_goal"))
        and isinstance(importance, int)
        and 1 <= importance <= 5
        and _is_nonempty_str(style)
        and has_motivation_signal
    )


def _pick_next_question_key(profile: dict, asked_counts: dict) -> str | None:
    """
    Choose the next question to ask, prioritizing required fields and avoiding repeats.
    """
    profile = profile or {}
    asked_counts = asked_counts or {}

    def asked_too_much(key: str) -> bool:
        return int(asked_counts.get(key, 0) or 0) >= _GOAL_DISCOVERY_MAX_ASKS_PER_FIELD

    # Required-ish first (to unlock app selection without stalling)
    if not _is_nonempty_str(profile.get("primary_goal")) and not asked_too_much("primary_goal"):
        return "primary_goal"

    if not _is_nonempty_str(profile.get("why")) and not asked_too_much("why"):
        return "why"

    importance = profile.get("importance_1_to_5")
    if not (isinstance(importance, int) and 1 <= importance <= 5) and not asked_too_much(
        "importance_1_to_5"
    ):
        return "importance_1_to_5"

    motivators = profile.get("motivators") or []
    stakes = profile.get("stakes")
    has_motivation_signal = (
        isinstance(motivators, list) and len([m for m in motivators if str(m).strip()]) > 0
    ) or _is_nonempty_str(stakes)
    if not has_motivation_signal and not asked_too_much("motivators"):
        return "motivators"

    if not _is_nonempty_str(profile.get("style")) and not asked_too_much("style"):
        return "style"

    # App intent is valuable for the next screen (apps), so ask it early.
    if not _is_nonempty_str(profile.get("app_intent_notes")) and not asked_too_much(
        "app_intent_notes"
    ):
        return "app_intent_notes"

    # Nice-to-haves (ask at most once or twice).
    if not _is_nonempty_str(profile.get("identity")) and not asked_too_much("identity"):
        return "identity"

    if not _is_nonempty_str(profile.get("preferred_name_for_user")) and not asked_too_much(
        "preferred_name_for_user"
    ):
        return "preferred_name_for_user"

    if not _is_nonempty_str(profile.get("preferred_name_for_assistant")) and not asked_too_much(
        "preferred_name_for_assistant"
    ):
        return "preferred_name_for_assistant"

    return None


def _render_question(question_key: str, profile: dict, ask_count: int) -> str:
    profile = profile or {}
    ask_count = max(0, int(ask_count or 0))

    goal = (profile.get("primary_goal") or "").strip()

    # Two variations per question (0 = first ask, 1+ = retry rephrase).
    if question_key == "primary_goal":
        return (
            "Let’s start simple: what’s the single goal that matters most to you right now?"
            if ask_count == 0
            else "Quick reset — what’s the #1 goal you want Pro Buddy to help protect this week?"
        )

    if question_key == "why":
        if goal:
            return (
                f"Why does “{goal}” matter to you personally?"
                if ask_count == 0
                else f"One level deeper: what would achieving “{goal}” change for you?"
            )
        return (
            "Why does that goal matter to you personally?"
            if ask_count == 0
            else "What’s the deeper reason this goal is important to you?"
        )

    if question_key == "importance_1_to_5":
        return (
            "On a scale of 1–5, how important is this goal to you right now?"
            if ask_count == 0
            else "Just a number 1–5 is perfect: how important is this goal right now?"
        )

    if question_key == "motivators":
        return (
            "When you’re tempted to drift, what usually pulls you back? Give me 1–3 motivators."
            if ask_count == 0
            else "If you had to pick 1–2 motivators that *actually work* for you, what are they?"
        )

    if question_key == "style":
        return (
            "How should I nudge you: gentle, direct, playful, or a mix?"
            if ask_count == 0
            else "What tone works best for you — gentle, direct, playful, or mixed?"
        )

    if question_key == "app_intent_notes":
        return (
            "Which apps are helpful for your goal, and which tend to pull you off track? (YouTube can be either — tell me when it helps vs when it becomes avoidance.)"
            if ask_count == 0
            else "Any apps that are ‘good when used intentionally’ but risky when you’re tired/bored? Tell me which ones and what the boundary is."
        )

    if question_key == "identity":
        return (
            "When you’re at your best, what identity fits you right now (e.g., writer, builder, athlete, learner)?"
            if ask_count == 0
            else "If you had to label ‘the version of you you’re building’, what would it be?"
        )

    if question_key == "preferred_name_for_user":
        return (
            "What name should I call you in notifications?"
            if ask_count == 0
            else "What should I call you?"
        )

    if question_key == "preferred_name_for_assistant":
        return (
            "And what would you like to call me?"
            if ask_count == 0
            else "Want to give me a nickname?"
        )

    # Fallback (shouldn’t happen)
    return "What would you like Pro Buddy to know so notifications feel helpful, not annoying?"


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


class OnboardingPreferencesRequest(BaseModel):
    """Request for saving onboarding preferences (challenges, habits - NOT primary goals)."""

    challenges: List[str] = []
    habits: List[str] = []
    distraction_hours: float = 0
    focus_duration_minutes: float = 0
    goal_clarity: int = 5
    productive_time: str = "Morning"
    check_in_frequency: str = "Daily"


class OnboardingPreferencesResponse(BaseModel):
    """Response for onboarding preferences."""

    challenges: List[str] = []
    habits: List[str] = []
    distraction_hours: float = 0
    focus_duration_minutes: float = 0
    goal_clarity: int = 5
    productive_time: str = "Morning"
    check_in_frequency: str = "Daily"


class GoalUpdateRequest(BaseModel):
    """Request for updating a goal."""

    content: str | None = None
    reason: str | None = None
    timeline: str | None = None


async def _bg_store_goal(vectorize, user_id: str, goal_id: str, content: str, reason: str | None):
    """Background task to store goal in Vectorize."""
    try:
        await vectorize.store_user_goal(
            user_id=user_id,
            goal_id=goal_id,
            content=content,
            reason=reason,
        )
    except Exception as e:
        print(f"Warning: Failed to store goal in Vectorize (background): {e}")


def reset_user_onboarding_data(uid: str):
    """Clear in-memory onboarding data for a user."""
    if uid in _goals_db:
        del _goals_db[uid]
    if uid in _app_selections_db:
        del _app_selections_db[uid]
    if uid in _notification_profile_db:
        del _notification_profile_db[uid]
    if uid in _onboarding_preferences_db:
        del _onboarding_preferences_db[uid]
    
    # Clear goal discovery sessions for this user
    sessions_to_remove = [k for k, v in _goal_discovery_sessions.items() if v.get("user_id") == uid]
    for k in sessions_to_remove:
        del _goal_discovery_sessions[k]


@router.post("/goals", response_model=GoalsResponse)
async def save_goals(
    request: GoalCreateRequest,
    background_tasks: BackgroundTasks,
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

    # Store in Cloudflare Vectorize (background task)
    if req and hasattr(req.app.state, "vectorize"):
        vectorize = req.app.state.vectorize
        background_tasks.add_task(
            _bg_store_goal,
            vectorize,
            uid,
            goal.id,
            goal.content,
            goal.reason,
        )

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


async def _bg_store_app_selection(
    vectorize,
    user_id: str,
    selection_id: str,
    app_name: str,
    package_name: str,
    reason: str,
    importance: int,
):
    """Background task to store app selection in Vectorize."""
    try:
        await vectorize.store_app_selection(
            user_id=user_id,
            selection_id=selection_id,
            app_name=app_name,
            package_name=package_name,
            reason=reason,
            importance=importance,
        )
    except Exception as e:
        print(f"Warning: Failed to store app selection in Vectorize (background): {e}")


@router.post("/apps", response_model=AppSelectionsResponse)
async def save_app_selections(
    request: AppSelectionsCreate,
    background_tasks: BackgroundTasks,
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

        # Store in Cloudflare Vectorize (background task)
        if req and hasattr(req.app.state, "vectorize"):
            vectorize = req.app.state.vectorize
            background_tasks.add_task(
                _bg_store_app_selection,
                vectorize,
                uid,
                selection.id,
                selection.app_name,
                selection.package_name,
                selection.reason,
                selection.importance_rating,
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


@router.post("/preferences", response_model=OnboardingPreferencesResponse)
async def save_onboarding_preferences(
    request: OnboardingPreferencesRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Save user's onboarding preferences (challenges, habits, etc.)
    
    These are routines/habits to help achieve goals, NOT the primary goals themselves.
    Primary goals are collected separately via Goal Discovery.
    """
    uid = current_user["uid"]
    
    prefs = {
        "challenges": request.challenges,
        "habits": request.habits,
        "distraction_hours": request.distraction_hours,
        "focus_duration_minutes": request.focus_duration_minutes,
        "goal_clarity": request.goal_clarity,
        "productive_time": request.productive_time,
        "check_in_frequency": request.check_in_frequency,
    }
    
    # Store in memory cache
    _onboarding_preferences_db[uid] = prefs
    
    # Persist to D1 for long-term storage
    if usage_store_service.configured:
        try:
            await usage_store_service.store_onboarding_preferences(
                user_id=uid,
                challenges=request.challenges,
                habits=request.habits,
                distraction_hours=request.distraction_hours,
                focus_duration_minutes=request.focus_duration_minutes,
                goal_clarity=request.goal_clarity,
                productive_time=request.productive_time,
                check_in_frequency=request.check_in_frequency,
            )
        except Exception as e:
            print(f"Warning: Failed to store onboarding preferences in D1: {e}")
    
    return OnboardingPreferencesResponse(**prefs)


@router.get("/preferences", response_model=OnboardingPreferencesResponse)
async def get_onboarding_preferences(
    current_user: dict = Depends(get_current_user),
):
    """Get user's onboarding preferences."""
    uid = current_user["uid"]
    
    # Try memory cache first
    prefs = _onboarding_preferences_db.get(uid)
    
    # If not in memory, try D1
    if not prefs and usage_store_service.configured:
        try:
            stored_prefs = await usage_store_service.get_onboarding_preferences(user_id=uid)
            if stored_prefs:
                prefs = {
                    "challenges": stored_prefs.get("challenges", []),
                    "habits": stored_prefs.get("habits", []),
                    "distraction_hours": stored_prefs.get("distraction_hours", 0),
                    "focus_duration_minutes": stored_prefs.get("focus_duration_minutes", 0),
                    "goal_clarity": stored_prefs.get("goal_clarity", 5),
                    "productive_time": stored_prefs.get("productive_time", "Morning"),
                    "check_in_frequency": stored_prefs.get("check_in_frequency", "Daily"),
                }
                # Cache in memory
                _onboarding_preferences_db[uid] = prefs
        except Exception as e:
            print(f"Warning: Failed to get onboarding preferences from D1: {e}")
    
    prefs = prefs or {}
    
    return OnboardingPreferencesResponse(
        challenges=prefs.get("challenges", []),
        habits=prefs.get("habits", []),
        distraction_hours=prefs.get("distraction_hours", 0),
        focus_duration_minutes=prefs.get("focus_duration_minutes", 0),
        goal_clarity=prefs.get("goal_clarity", 5),
        productive_time=prefs.get("productive_time", "Morning"),
        check_in_frequency=prefs.get("check_in_frequency", "Daily"),
    )


@router.put("/goals/{goal_id}", response_model=GoalsResponse)
async def update_goal(
    goal_id: str,
    request: GoalUpdateRequest,
    current_user: dict = Depends(get_current_user),
):
    """Update an existing goal."""
    uid = current_user["uid"]
    goals = _goals_db.get(uid, [])
    
    for goal in goals:
        if goal.id == goal_id:
            if request.content is not None:
                goal.content = request.content
            if request.reason is not None:
                goal.reason = request.reason
            if request.timeline is not None:
                goal.timeline = request.timeline
            
            return GoalsResponse(goals=goals)
    
    raise HTTPException(status_code=404, detail="Goal not found")


@router.delete("/goals/{goal_id}")
async def delete_goal(
    goal_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Delete a goal."""
    uid = current_user["uid"]
    goals = _goals_db.get(uid, [])
    
    for i, goal in enumerate(goals):
        if goal.id == goal_id:
            goals.pop(i)
            return {"success": True, "message": "Goal deleted"}
    
    raise HTTPException(status_code=404, detail="Goal not found")


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

    # Get goals, apps, and profile
    goals = _goals_db.get(uid, [])
    apps = _app_selections_db.get(uid, [])
    profile = _notification_profile_db.get(uid, {})

    # Check if we have a primary goal from Goal Discovery (preferred)
    # or from direct goal input
    has_primary_goal = _is_nonempty_str(profile.get("primary_goal")) or len(goals) > 0

    if not has_primary_goal:
        raise HTTPException(
            status_code=400,
            detail="Please complete Goal Discovery or set at least one goal before completing onboarding",
        )

    # Generate final summary
    summary = None
    if req and hasattr(req.app.state, "gemini") and goals:
        gemini = req.app.state.gemini
        goals_data = [{"content": g.content, "reason": g.reason} for g in goals]
        summary = await gemini.generate_goals_summary(goals_data)

    # Mark user as onboarded
    update_onboarding_status(uid, True)

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

    # NOTE: We intentionally do NOT seed primary_goal from goals_db here.
    # The goals in goals_db from the new onboarding flow are routines/habits,
    # NOT the user's actual primary goals. Goal Discovery should ask for
    # the user's primary goal fresh, without assuming we already know it.
    profile_dict = dict(existing_profile or {})
    done = _is_profile_min_complete(profile_dict)

    asked: dict = {}
    if done:
        ai_message = (
            "Nice — I already have enough to personalize your notifications. "
            "If you want to refine anything, just tell me what to change. "
            "Otherwise, you can continue to app selection."
        )
    else:
        q_key = _pick_next_question_key(profile_dict, asked) or "primary_goal"
        ai_message = _render_question(q_key, profile_dict, asked.get(q_key, 0))
        asked[q_key] = int(asked.get(q_key, 0) or 0) + 1

    # Create in-memory session state for robust, non-repeating flow.
    now_iso = datetime.utcnow().isoformat()
    _goal_discovery_sessions[session_id] = {
        "user_id": uid,
        "messages": [
            {
                "role": "assistant",
                "content": ai_message,
                "timestamp": now_iso,
            }
        ],
        "asked": asked,
        "turns": 0,
        "created_at": now_iso,
    }

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

    # In-memory session state (preferred for deterministic ordering + anti-repeat).
    session = _goal_discovery_sessions.get(body.session_id)
    if not isinstance(session, dict) or session.get("user_id") != uid:
        # Re-hydrate best-effort from Vectorize if available.
        session = {
            "user_id": uid,
            "messages": list(history or []),
            "asked": {},
            "turns": 0,
            "created_at": datetime.utcnow().isoformat(),
        }
        # Approximate turns if we have any history.
        if session["messages"]:
            session["turns"] = len([m for m in session["messages"] if m.get("role") == "user"])
        _goal_discovery_sessions[body.session_id] = session

    # Conservative early-exit: user explicitly wants to stop/skip.
    if _is_goal_discovery_exit_intent(body.message):
        ai_message = (
            "All good — we can stop here. You can always refine this later. "
            "Go ahead and continue to app selection when you're ready."
        )

        # Store user message in memory + Vectorize
        now_iso = datetime.utcnow().isoformat()
        session_messages = session.get("messages") or []
        session_messages.append({"role": "user", "content": body.message, "timestamp": now_iso})
        session_messages.append({"role": "assistant", "content": ai_message, "timestamp": now_iso})
        session["messages"] = session_messages
        session["turns"] = int(session.get("turns", 0) or 0) + 1

        if vectorize:
            await vectorize.store_goal_discovery_message(
                user_id=uid,
                session_id=body.session_id,
                message_id=str(uuid4()),
                role="user",
                content=body.message,
                timestamp=now_iso,
            )
            await vectorize.store_goal_discovery_message(
                user_id=uid,
                session_id=body.session_id,
                message_id=str(uuid4()),
                role="assistant",
                content=ai_message,
                timestamp=now_iso,
            )

        # Return done=true with whatever profile we currently have.
        updated_profile = dict(existing_profile or {})
        _notification_profile_db[uid] = updated_profile or {}

        profile = None
        if updated_profile:
            profile_kwargs = dict(updated_profile)
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
            done=True,
            profile=profile,
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

    # For Gemini context, prefer full ordered in-memory session history.
    history_for_model = session.get("messages") or history or []
    history_for_model = history_for_model[-12:]

    # Append user message to in-memory session state (after capturing model history).
    now_iso = datetime.utcnow().isoformat()
    session_messages = session.get("messages") or []
    session_messages.append({"role": "user", "content": body.message, "timestamp": now_iso})
    session["messages"] = session_messages
    session["turns"] = int(session.get("turns", 0) or 0) + 1

    updated_profile = existing_profile
    gemini_profile_update = {}

    if gemini:
        result = await gemini.goal_discovery_step(
            user_message=body.message,
            conversation_history=history_for_model,
            existing_profile=existing_profile,
        )
        gemini_profile_update = result.get("profile") or {}
        updated_profile = _merge_notification_profile(
            existing_profile, gemini_profile_update
        )

    # Lightweight deterministic parsing for key fields (helps when model is flaky).
    manual_update: dict = {}
    raw = (body.message or "").strip()
    if raw.isdigit():
        n = int(raw)
        if 1 <= n <= 5:
            manual_update["importance_1_to_5"] = n

    style_token = raw.lower()
    if style_token in {"gentle", "direct", "playful", "mixed", "mix"}:
        manual_update["style"] = "mixed" if style_token == "mix" else style_token

    if manual_update:
        updated_profile = _merge_notification_profile(updated_profile or {}, manual_update)

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

    # Determine whether we are done (deterministic guardrails).
    hard_stop = int(session.get("turns", 0) or 0) >= _GOAL_DISCOVERY_MAX_USER_TURNS
    done = _is_profile_min_complete(updated_profile or {}) or hard_stop

    asked = session.get("asked") or {}
    next_key = None if done else _pick_next_question_key(updated_profile or {}, asked)
    if next_key is None:
        # If we can't find another useful question, end the flow.
        done = True

    if done:
        ai_message = (
            "Perfect — that’s enough for me to personalize your nudges. "
            "Next, select the apps that help (and the ones that distract) so we can be smarter about notifications."
        )
        if hard_stop and not _is_profile_min_complete(updated_profile or {}):
            ai_message = (
                "Thanks — that’s enough for now. We can refine this later. "
                "Next, select the apps that help (and the ones that distract)."
            )
    else:
        ask_count = int(asked.get(next_key, 0) or 0)
        ai_message = _render_question(next_key, updated_profile or {}, ask_count)
        asked[next_key] = ask_count + 1
        session["asked"] = asked

    # Append assistant message to in-memory session state.
    session_messages = session.get("messages") or []
    session_messages.append({"role": "assistant", "content": ai_message, "timestamp": now_iso})
    session["messages"] = session_messages

    # Store assistant message (Vectorize)
    if vectorize:
        await vectorize.store_goal_discovery_message(
            user_id=uid,
            session_id=body.session_id,
            message_id=str(uuid4()),
            role="assistant",
            content=ai_message,
            timestamp=now_iso,
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
