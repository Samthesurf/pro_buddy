"""App selection and classification models."""

from datetime import datetime
from enum import Enum
from typing import Optional, List
from pydantic import BaseModel, Field


class AppCategory(str, Enum):
    """Categories for app classification."""

    PRODUCTIVITY = "productivity"
    SOCIAL = "social"
    ENTERTAINMENT = "entertainment"
    GAMING = "gaming"
    UTILITY = "utility"
    HEALTH = "health"
    EDUCATION = "education"
    COMMUNICATION = "communication"
    FINANCE = "finance"
    NEWS = "news"
    SHOPPING = "shopping"
    TRAVEL = "travel"
    OTHER = "other"


class InstalledApp(BaseModel):
    """Represents an installed app on the device."""

    package_name: str = Field(..., description="Android package name")
    app_name: str = Field(..., description="Display name of the app")
    category: Optional[str] = None
    is_system_app: bool = False


class AppSelectionBase(BaseModel):
    """Base app selection model."""

    package_name: str = Field(..., description="Android package name")
    app_name: str = Field(..., description="Display name of the app")
    reason: str = Field(
        ..., min_length=5, description="Why this app helps achieve goals"
    )
    importance_rating: int = Field(
        ..., ge=1, le=5, description="How important (1-5)"
    )


class AppSelectionCreate(AppSelectionBase):
    """Model for creating an app selection."""

    pass


class AppSelection(AppSelectionBase):
    """Full app selection model."""

    id: str
    user_id: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class AppClassification(BaseModel):
    """AI-generated classification of an app."""

    package_name: str
    app_name: str
    category: AppCategory
    description: str = Field(..., description="What the app is typically used for")
    typical_uses: List[str] = Field(
        default_factory=list, description="Common use cases"
    )
    classified_at: datetime = Field(default_factory=datetime.utcnow)


class AppSelectionsCreate(BaseModel):
    """Model for bulk creating app selections."""

    apps: List[AppSelectionCreate] = Field(..., min_length=1)