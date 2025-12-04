"""
Authentication router.
Handles Firebase token verification and user management.
"""

from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel

from ..services.auth_service import auth_service
from ..models.user import UserResponse
from ..dependencies import get_current_user


router = APIRouter()


class TokenVerifyResponse(BaseModel):
    """Response for token verification."""

    user: UserResponse
    is_new_user: bool


# Simple in-memory user storage (replace with database in production)
_users_db: dict = {}


@router.post("/verify", response_model=TokenVerifyResponse)
async def verify_token(current_user: dict = Depends(get_current_user)):
    """
    Verify Firebase token and get/create user.

    This endpoint should be called after the user signs in with Firebase
    to register them in the backend or retrieve their existing data.
    """
    uid = current_user["uid"]
    is_new_user = uid not in _users_db

    if is_new_user:
        # Create new user
        from datetime import datetime

        _users_db[uid] = {
            "id": uid,
            "email": current_user.get("email", ""),
            "display_name": current_user.get("name"),
            "photo_url": current_user.get("picture"),
            "onboarding_complete": False,
            "created_at": datetime.utcnow(),
        }

    user_data = _users_db[uid]

    return TokenVerifyResponse(
        user=UserResponse(
            id=user_data["id"],
            email=user_data["email"],
            display_name=user_data.get("display_name"),
            photo_url=user_data.get("photo_url"),
            onboarding_complete=user_data.get("onboarding_complete", False),
            created_at=user_data["created_at"],
        ),
        is_new_user=is_new_user,
    )


@router.get("/user/profile", response_model=UserResponse)
async def get_user_profile(current_user: dict = Depends(get_current_user)):
    """Get the current user's profile."""
    uid = current_user["uid"]

    if uid not in _users_db:
        raise HTTPException(status_code=404, detail="User not found")

    user_data = _users_db[uid]

    return UserResponse(
        id=user_data["id"],
        email=user_data["email"],
        display_name=user_data.get("display_name"),
        photo_url=user_data.get("photo_url"),
        onboarding_complete=user_data.get("onboarding_complete", False),
        created_at=user_data["created_at"],
    )

