"""
Goal discovery (motivators + notification profile) models.

These models power a back-and-forth conversation that helps the system
understand what matters to the user and how to nudge them.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional, List, Literal

from pydantic import BaseModel, Field


NotificationStyle = Literal["gentle", "direct", "playful", "mixed"]


class NotificationProfile(BaseModel):
    """Structured, persisted profile used to personalize nudges/notifications."""

    user_id: str

    # Identity + goal framing
    identity: Optional[str] = Field(
        None, description="Identity label the user resonates with (e.g., 'writer')"
    )
    primary_goal: Optional[str] = Field(
        None, description="The single most important goal right now"
    )
    why: Optional[str] = Field(None, description="Why the goal matters to them")

    # Motivation + meaning
    motivators: List[str] = Field(default_factory=list)
    stakes: Optional[str] = Field(
        None, description="What it would cost them emotionally/practically to give up"
    )
    importance_1_to_5: Optional[int] = Field(
        None, ge=1, le=5, description="How much this goal matters to them (1-5)"
    )

    # Notification preferences
    style: NotificationStyle = "gentle"
    preferred_name_for_user: Optional[str] = None
    preferred_name_for_assistant: Optional[str] = None

    # App-specific intent/rules
    helpful_apps: List[str] = Field(default_factory=list)
    risky_apps: List[str] = Field(default_factory=list)
    app_intent_notes: Optional[str] = Field(
        None,
        description="Freeform notes like 'YouTube helps when learning writing, hurts when doomscrolling'",
    )

    updated_at: datetime = Field(default_factory=datetime.utcnow)


class GoalDiscoveryStartRequest(BaseModel):
    """Start or reset a goal-discovery session."""

    reset: bool = False


class GoalDiscoveryMessageRequest(BaseModel):
    """Send a message within a goal-discovery session."""

    session_id: str = Field(..., min_length=1)
    message: str = Field(..., min_length=1, max_length=2000)


class GoalDiscoveryResponse(BaseModel):
    """Response from goal-discovery assistant."""

    session_id: str
    message: str
    done: bool = False
    profile: Optional[NotificationProfile] = None

