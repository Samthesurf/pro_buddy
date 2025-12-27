"""
Authentication router.
Handles Firebase token verification and user management.
"""

from typing import Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Header, Request
from pydantic import BaseModel

from ..services.auth_service import auth_service
from ..services.usage_store_service import usage_store_service
from ..models.user import UserResponse
from ..dependencies import get_current_user


router = APIRouter()


class TokenVerifyResponse(BaseModel):
    """Response for token verification."""

    user: UserResponse
    is_new_user: bool


# In-memory cache for users (hydrated from D1 on login, improves performance)
# This is now just a cache, D1 is the source of truth
_users_cache: dict = {}


async def update_onboarding_status(uid: str, status: bool):
    """Update the onboarding status for a user."""
    # Update cache
    if uid in _users_cache:
        _users_cache[uid]["onboarding_complete"] = status
    
    # Persist to D1
    if usage_store_service.configured:
        try:
            await usage_store_service.update_onboarding_status(
                user_id=uid, onboarding_complete=status
            )
        except Exception as e:
            print(f"Warning: Failed to update onboarding status in D1: {e}")


async def _hydrate_user_from_d1(uid: str) -> Optional[dict]:
    """Load user from D1 into memory cache."""
    if not usage_store_service.configured:
        return None
    
    try:
        user_data = await usage_store_service.get_user(user_id=uid)
        if user_data:
            # Convert D1 format to internal format
            _users_cache[uid] = {
                "id": user_data["id"],
                "email": user_data["email"],
                "display_name": user_data.get("display_name"),
                "photo_url": user_data.get("photo_url"),
                "onboarding_complete": user_data.get("onboarding_complete", False),
                "created_at": datetime.fromisoformat(user_data["created_at"].replace("Z", "+00:00")),
            }
            return _users_cache[uid]
    except Exception as e:
        print(f"Warning: Failed to hydrate user from D1: {e}")
    
    return None


async def _persist_user_to_d1(uid: str, user_data: dict) -> None:
    """Save user to D1."""
    if not usage_store_service.configured:
        return
    
    try:
        await usage_store_service.upsert_user(
            user_id=uid,
            email=user_data["email"],
            display_name=user_data.get("display_name"),
            photo_url=user_data.get("photo_url"),
            onboarding_complete=user_data.get("onboarding_complete", False),
        )
    except Exception as e:
        print(f"Warning: Failed to persist user to D1: {e}")


@router.post("/verify", response_model=TokenVerifyResponse)
async def verify_token(current_user: dict = Depends(get_current_user)):
    """
    Verify Firebase token and get/create user.

    This endpoint should be called after the user signs in with Firebase
    to register them in the backend or retrieve their existing data.
    """
    uid = current_user["uid"]
    is_new_user = False
    
    # Check cache first
    if uid in _users_cache:
        user_data = _users_cache[uid]
    else:
        # Try to hydrate from D1
        user_data = await _hydrate_user_from_d1(uid)
    
    if not user_data:
        # New user - create them
        is_new_user = True
        user_data = {
            "id": uid,
            "email": current_user.get("email", ""),
            "display_name": current_user.get("name"),
            "photo_url": current_user.get("picture"),
            "onboarding_complete": False,
            "created_at": datetime.utcnow(),
        }
        
        # Store in cache
        _users_cache[uid] = user_data
        
        # Persist to D1
        await _persist_user_to_d1(uid, user_data)
    else:
        # Existing user - update their profile info from Firebase (may have changed)
        updated = False
        if current_user.get("name") and current_user.get("name") != user_data.get("display_name"):
            user_data["display_name"] = current_user.get("name")
            updated = True
        if current_user.get("picture") and current_user.get("picture") != user_data.get("photo_url"):
            user_data["photo_url"] = current_user.get("picture")
            updated = True
        
        if updated:
            _users_cache[uid] = user_data
            await _persist_user_to_d1(uid, user_data)

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
    
    # Check cache first
    if uid in _users_cache:
        user_data = _users_cache[uid]
    else:
        # Try to hydrate from D1
        user_data = await _hydrate_user_from_d1(uid)

    if not user_data:
        raise HTTPException(status_code=404, detail="User not found")

    return UserResponse(
        id=user_data["id"],
        email=user_data["email"],
        display_name=user_data.get("display_name"),
        photo_url=user_data.get("photo_url"),
        onboarding_complete=user_data.get("onboarding_complete", False),
        created_at=user_data["created_at"],
    )


@router.delete("/user/reset")
async def reset_user_account(
    req: Request,
    current_user: dict = Depends(get_current_user)
):
    """
    Reset user account to a fresh state.
    Deletes all data in D1 and Vectorize, and clears in-memory state.
    """
    uid = current_user["uid"]

    # 1. Clear in-memory user cache
    if uid in _users_cache:
        # Reset to initial state instead of deleting, so they stay logged in
        _users_cache[uid]["onboarding_complete"] = False
        
    # 2. Clear in-memory onboarding data
    # Import here to avoid circular dependency
    from .onboarding import reset_user_onboarding_data
    await reset_user_onboarding_data(uid)

    # 3. Delete from D1 (Usage Store) - this handles all persistent data
    try:
        await usage_store_service.delete_user_data(uid)
    except Exception as e:
        print(f"Error deleting user data from Usage Store: {e}")

    # 4. Delete from Vectorize
    if hasattr(req.app.state, "vectorize"):
        try:
            await req.app.state.vectorize.delete_user_data(uid)
        except Exception as e:
            print(f"Error deleting user data from Vectorize: {e}")

    # 5. Update local cache to reflect reset state
    if uid in _users_cache:
        await _persist_user_to_d1(uid, _users_cache[uid])

    return {"success": True, "message": "User account reset successfully"}
