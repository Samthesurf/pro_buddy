"""
Shared FastAPI dependencies.
"""

from typing import Optional
from fastapi import Header, HTTPException

from .services.auth_service import auth_service, AuthService


def get_current_user(authorization: Optional[str] = Header(None)) -> dict:
    """
    Dependency to get current authenticated user.

    Args:
        authorization: Bearer token from Authorization header

    Returns:
        User data from verified token

    Raises:
        HTTPException: If token is invalid or missing
    """
    # In development mode (Firebase not initialized), allow requests without auth
    if not AuthService._initialized:
        if not authorization:
            # Return a default dev user when no auth header is provided
            return {
                "uid": "dev_user_123",
                "email": "dev@example.com",
                "name": "Developer",
            }
        # If auth header is provided, still try to verify it
        if not authorization.startswith("Bearer "):
            return {
                "uid": "dev_user_123",
                "email": "dev@example.com",
                "name": "Developer",
            }
        token = authorization[7:]
        user_data = auth_service.verify_token(token)
        return user_data or {
            "uid": "dev_user_123",
            "email": "dev@example.com",
            "name": "Developer",
        }
    
    # Production mode - require authentication
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header required")

    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization format")

    token = authorization[7:]  # Remove "Bearer " prefix

    user_data = auth_service.verify_token(token)
    if not user_data:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    return user_data
