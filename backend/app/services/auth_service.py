"""
Firebase Authentication Service.
Handles token verification and user management.
"""

from typing import Optional, Dict, Any
from datetime import datetime
import firebase_admin
from firebase_admin import auth, credentials

from ..config import settings


class AuthService:
    """Service for Firebase authentication."""

    _initialized = False

    def __init__(self):
        """Initialize Firebase Admin SDK."""
        if not AuthService._initialized:
            try:
                cred = credentials.Certificate(settings.firebase_credentials_path)
                firebase_admin.initialize_app(cred)
                AuthService._initialized = True
            except Exception as e:
                print(f"Firebase initialization error: {e}")
                # For development, allow running without Firebase
                print("Running without Firebase authentication")

    def verify_token(self, id_token: str) -> Optional[Dict[str, Any]]:
        """
        Verify a Firebase ID token.

        Args:
            id_token: The Firebase ID token from the client

        Returns:
            Decoded token data if valid, None otherwise
        """
        if not AuthService._initialized:
            # Development mode - return mock user
            return {
                "uid": "dev_user_123",
                "email": "dev@example.com",
                "name": "Developer",
            }

        try:
            decoded_token = auth.verify_id_token(id_token)
            return {
                "uid": decoded_token["uid"],
                "email": decoded_token.get("email"),
                "name": decoded_token.get("name"),
                "picture": decoded_token.get("picture"),
            }
        except auth.InvalidIdTokenError:
            print("Invalid ID token")
            return None
        except auth.ExpiredIdTokenError:
            print("Expired ID token")
            return None
        except Exception as e:
            print(f"Token verification error: {e}")
            return None

    def get_user(self, uid: str) -> Optional[Dict[str, Any]]:
        """
        Get user information from Firebase.

        Args:
            uid: Firebase user ID

        Returns:
            User data if found, None otherwise
        """
        if not AuthService._initialized:
            return {
                "uid": uid,
                "email": "dev@example.com",
                "display_name": "Developer",
            }

        try:
            user = auth.get_user(uid)
            return {
                "uid": user.uid,
                "email": user.email,
                "display_name": user.display_name,
                "photo_url": user.photo_url,
                "disabled": user.disabled,
                "created_at": datetime.fromtimestamp(
                    user.user_metadata.creation_timestamp / 1000
                )
                if user.user_metadata.creation_timestamp
                else None,
            }
        except auth.UserNotFoundError:
            return None
        except Exception as e:
            print(f"Error getting user: {e}")
            return None


# Singleton instance
auth_service = AuthService()

