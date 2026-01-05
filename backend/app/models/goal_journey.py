"""Goal Journey models for the Goals feature."""

from enum import Enum
from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field
import uuid


class StepStatus(str, Enum):
    """Status of a journey step."""
    LOCKED = "locked"
    AVAILABLE = "available"
    IN_PROGRESS = "inprogress"
    COMPLETED = "completed"
    SKIPPED = "skipped"
    ALTERNATIVE = "alternative"


class PathType(str, Enum):
    """Type of path in the journey map."""
    MAIN = "main"
    ALTERNATIVE = "alternative"
    COMPLETED = "completed"


class MapPosition(BaseModel):
    """Position of a node on the journey map canvas."""
    x: float = Field(..., ge=0.0, le=1.0, description="X coordinate (0.0 - 1.0)")
    y: float = Field(..., ge=0.0, le=1.0, description="Y coordinate (0.0 - 1.0)")
    layer: int = Field(..., ge=0, description="Depth level in the tree")


class GoalStepBase(BaseModel):
    """Base model for a journey step."""
    title: str = Field(..., min_length=1, description="Step title")
    description: str = Field("", description="What this step entails")
    estimated_days: int = Field(14, ge=1, description="Estimated days to complete")


class GoalStepCreate(GoalStepBase):
    """Model for creating a step (from AI generation)."""
    prerequisites: List[str] = Field(default_factory=list)
    alternatives: List[str] = Field(default_factory=list)
    metadata: Optional[Dict[str, Any]] = None


class GoalStep(GoalStepBase):
    """Full goal step model with all fields."""
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    journey_id: str
    custom_title: Optional[str] = None
    order_index: int = 0
    status: StepStatus = StepStatus.LOCKED
    prerequisites: List[str] = Field(default_factory=list)
    alternatives: List[str] = Field(default_factory=list)
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    notes: List[str] = Field(default_factory=list)
    metadata: Optional[Dict[str, Any]] = None
    position: MapPosition = Field(
        default_factory=lambda: MapPosition(x=0.5, y=0.0, layer=0)
    )
    path_type: PathType = PathType.MAIN
    actual_days_spent: Optional[int] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

    @property
    def display_title(self) -> str:
        """Return custom title if set, otherwise original title."""
        return self.custom_title or self.title

    @property
    def is_unlocked(self) -> bool:
        """Whether the step can be interacted with."""
        return self.status not in (StepStatus.LOCKED, StepStatus.ALTERNATIVE)

    @property
    def is_on_main_path(self) -> bool:
        """Whether this step is on the main journey path."""
        return self.path_type in (PathType.MAIN, PathType.COMPLETED)

    class Config:
        from_attributes = True


class GoalJourneyCreate(BaseModel):
    """Model for generating a new journey."""
    goal_content: str = Field(..., min_length=10, description="The user's goal")
    goal_reason: Optional[str] = Field(None, description="Why this goal is important")
    goal_id: Optional[str] = Field(None, description="Reference to existing goal")


class GoalJourney(BaseModel):
    """Complete goal journey with all steps and metadata."""
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str
    goal_id: Optional[str] = None
    goal_content: str = Field(..., description="The destination - user's main goal")
    goal_reason: Optional[str] = None
    steps: List[GoalStep] = Field(default_factory=list)
    current_step_index: int = 0
    overall_progress: float = Field(0.0, ge=0.0, le=1.0)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: Optional[datetime] = None
    journey_started_at: datetime = Field(default_factory=datetime.utcnow)
    is_ai_generated: bool = True
    ai_notes: Optional[str] = None
    map_width: float = 1000.0
    map_height: float = 2000.0

    @property
    def main_path(self) -> List[GoalStep]:
        """Get only the main path steps (excluding alternatives)."""
        return sorted(
            [s for s in self.steps if s.is_on_main_path],
            key=lambda s: s.order_index
        )

    @property
    def current_step(self) -> Optional[GoalStep]:
        """Get the current active step."""
        main = self.main_path
        if 0 <= self.current_step_index < len(main):
            return main[self.current_step_index]
        # Fallback: find in_progress or available step
        for step in main:
            if step.status == StepStatus.IN_PROGRESS:
                return step
        for step in main:
            if step.status == StepStatus.AVAILABLE:
                return step
        return main[0] if main else None

    @property
    def completed_steps(self) -> List[GoalStep]:
        """Get completed steps."""
        return [s for s in self.main_path if s.status == StepStatus.COMPLETED]

    @property
    def remaining_steps(self) -> List[GoalStep]:
        """Get remaining steps (not completed or skipped)."""
        return [
            s for s in self.main_path
            if s.status not in (StepStatus.COMPLETED, StepStatus.SKIPPED)
        ]

    @property
    def steps_to_destination(self) -> int:
        """Steps until destination."""
        return len(self.remaining_steps)

    @property
    def is_complete(self) -> bool:
        """Is journey complete?"""
        return self.overall_progress >= 1.0 or len(self.remaining_steps) == 0

    class Config:
        from_attributes = True


class JourneyAdjustmentRequest(BaseModel):
    """Request model for AI-powered journey adjustment."""
    journey_id: str
    current_activity: str = Field(
        ...,
        min_length=5,
        description="What the user is currently doing"
    )
    additional_context: Optional[str] = None


class JourneyAdjustmentResponse(BaseModel):
    """Response model for journey adjustment."""
    journey: GoalJourney
    changes_made: List[str] = Field(
        default_factory=list,
        description="Description of changes made"
    )
    ai_message: str = Field(..., description="Encouraging message about the adjustment")


class StepStatusUpdate(BaseModel):
    """Request model for updating step status."""
    status: StepStatus
    notes: Optional[str] = Field(None, description="Optional note to add")


class StepTitleUpdate(BaseModel):
    """Request model for updating step title."""
    custom_title: str = Field(..., min_length=1)


class StepNoteAdd(BaseModel):
    """Request model for adding a note to a step."""
    note: str = Field(..., min_length=1)


class JourneyGenerateRequest(BaseModel):
    """Request model for generating a new journey."""
    goal_content: str = Field(..., min_length=10)
    goal_reason: Optional[str] = None
    goal_id: Optional[str] = None
    # Optional context from notification profile
    identity: Optional[str] = None
    challenges: Optional[List[str]] = None


class JourneyGenerateResponse(BaseModel):
    """Response model for journey generation."""
    journey: GoalJourney
    ai_message: str = Field(..., description="AI's overview of the journey")
