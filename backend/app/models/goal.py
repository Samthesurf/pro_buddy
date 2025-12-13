"""Goal models."""

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field


class GoalBase(BaseModel):
    """Base goal model."""

    content: str = Field(..., min_length=10, description="The user's goal")
    reason: Optional[str] = Field(None, description="Why this goal is important")
    timeline: Optional[str] = Field(None, description="When they want to achieve it")


class GoalCreate(GoalBase):
    """Model for creating a goal."""

    pass


class Goal(GoalBase):
    """Full goal model with all fields."""

    id: str
    user_id: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class GoalsProfileCreate(BaseModel):
    """Model for creating/updating a goals profile."""

    goals: List[GoalCreate] = Field(..., min_length=1)


class GoalsProfile(BaseModel):
    """Complete goals profile for a user."""

    user_id: str
    goals: List[Goal]
    summary: Optional[str] = Field(None, description="AI-generated summary of goals")
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True









