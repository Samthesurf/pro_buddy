"""
Application configuration using pydantic-settings.
Environment variables are loaded from .env file.
"""

from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Application
    app_name: str = "Pro Buddy API"
    app_version: str = "1.0.0"
    debug: bool = False

    # Server
    host: str = "0.0.0.0"
    port: int = 8000

    # Firebase
    firebase_credentials_path: str = "firebase-credentials.json"

    # Google Gemini
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.5-flash-preview-09-2025"

    # Cloudflare
    cloudflare_account_id: str = ""
    cloudflare_api_token: str = ""
    cloudflare_embedding_model: str = "@cf/baai/bge-m3"

    # Cloudflare Vectorize
    vectorize_index_users: str = "pro-buddy-users"
    vectorize_index_apps: str = "pro-buddy-apps"

    # Usage history persistence (Cloudflare Worker + D1)
    # If set, the backend will store usage history + cooldowns via the Worker
    # instead of keeping in-memory dictionaries.
    usage_store_worker_url: str = "https://pro-buddy-usage-store.hawkbuddy.workers.dev"
    usage_store_worker_token: str = "sammysurf"

    # Rate Limiting
    rate_limit_per_minute: int = 60

    # Notification Settings
    encouraging_cooldown_hours: int = 1
    reminder_cooldown_minutes: int = 15


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


# Export for easy access
settings = get_settings()
