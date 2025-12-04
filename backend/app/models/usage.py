"""Usage monitoring and feedback models."""

from datetime import datetime
from enum import Enum
from typing import Optional, List
from pydantic import BaseModel, Field


class AlignmentStatus(str, Enum):
    """Alignment status of app usage with goals."""

    ALIGNED = "aligned"
    NEUTRAL = "neutral"
    MISALIGNED = "misaligned"


class AppUsageEvent(BaseModel):
    """Represents an app usage event from the device."""

    package_name: str = Field(..., description="Android package name")
    app_name: str = Field(..., description="Display name of the app")
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    duration_ms: Optional[int] = Field(None, description="Duration in milliseconds")


class UsageFeedbackBase(BaseModel):
    """Base usage feedback model."""

    package_name: str
    app_name: str
    alignment: AlignmentStatus
    message: str = Field(..., description="Feedback message for the user")
    reason: Optional[str] = Field(None, description="Explanation of alignment")


class UsageFeedback(UsageFeedbackBase):
    """Full usage feedback model."""

    id: str
    user_id: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    notification_sent: bool = False

    class Config:
        from_attributes = True


class UsageFeedbackResponse(BaseModel):
    """Response for app usage analysis."""

    aligned: bool
    alignment_status: AlignmentStatus
    message: str
    reason: Optional[str] = None
    should_notify: bool = True


class DailySummary(BaseModel):
    """Daily usage summary."""

    user_id: str
    date: datetime
    aligned_count: int = 0
    neutral_count: int = 0
    misaligned_count: int = 0
    total_aligned_time_ms: int = 0
    total_misaligned_time_ms: int = 0
    alignment_score: float = Field(
        ..., ge=0.0, le=100.0, description="Score from 0-100"
    )
    feedback_items: List[UsageFeedback] = Field(default_factory=list)

    @property
    def total_count(self) -> int:
        """Total number of app usage events."""
        return self.aligned_count + self.neutral_count + self.misaligned_count

