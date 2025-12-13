"""User models."""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, Field


class UserBase(BaseModel):
    """Base user model."""

    email: EmailStr
    display_name: Optional[str] = None
    photo_url: Optional[str] = None


class UserCreate(UserBase):
    """Model for creating a user."""

    firebase_uid: str = Field(..., description="Firebase user ID")


class User(UserBase):
    """Full user model with all fields."""

    id: str = Field(..., description="Internal user ID")
    firebase_uid: str = Field(..., description="Firebase user ID")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: Optional[datetime] = None
    onboarding_complete: bool = False

    class Config:
        from_attributes = True


class UserResponse(BaseModel):
    """User response for API."""

    id: str
    email: EmailStr
    display_name: Optional[str] = None
    photo_url: Optional[str] = None
    onboarding_complete: bool = False
    created_at: datetime









