"""Pydantic models for API requests and responses."""

from .user import User, UserCreate, UserResponse
from .goal import Goal, GoalCreate, GoalsProfile, GoalsProfileCreate
from .app_selection import (
    AppSelection,
    AppSelectionCreate,
    AppClassification,
    InstalledApp,
)
from .usage import (
    AppUsageEvent,
    UsageFeedback,
    UsageFeedbackResponse,
    DailySummary,
    AlignmentStatus,
)
from .progress_score import (
    FinalizeTodayProgressRequest,
    FinalizeTodayProgressResponse,
    LatestProgressScoreResponse,
    ProgressScoreItem,
    ProgressScoreMessage,
)

__all__ = [
    # User
    "User",
    "UserCreate",
    "UserResponse",
    # Goal
    "Goal",
    "GoalCreate",
    "GoalsProfile",
    "GoalsProfileCreate",
    # App Selection
    "AppSelection",
    "AppSelectionCreate",
    "AppClassification",
    "InstalledApp",
    # Usage
    "AppUsageEvent",
    "UsageFeedback",
    "UsageFeedbackResponse",
    "DailySummary",
    "AlignmentStatus",
    # Progress Score
    "ProgressScoreMessage",
    "FinalizeTodayProgressRequest",
    "ProgressScoreItem",
    "FinalizeTodayProgressResponse",
    "LatestProgressScoreResponse",
]