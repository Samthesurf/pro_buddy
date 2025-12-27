"""App use cases models for caching AI-generated suggestions."""

from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class AppInfo(BaseModel):
    """Basic app info for use case requests."""

    package_name: str = Field(..., description="Android package name")
    app_name: str = Field(..., description="Display name of the app")


class AppUseCasesRequest(BaseModel):
    """Request model for bulk use cases fetch."""

    apps: List[AppInfo] = Field(..., min_length=1, max_length=200)


class AppUseCaseEntry(BaseModel):
    """Single app's use cases."""

    package_name: str
    app_name: str
    use_cases: List[str] = Field(default_factory=list)
    category: Optional[str] = None
    from_cache: bool = False  # Indicates if this was from DB cache


class AppUseCasesResponse(BaseModel):
    """Response model for bulk use cases."""

    results: dict[str, AppUseCaseEntry] = Field(
        default_factory=dict,
        description="Map of package_name to use case entry"
    )
    cached_count: int = 0
    generated_count: int = 0


class PopulateRequest(BaseModel):
    """Request model for database population script."""

    apps: List[AppInfo]
    force_refresh: bool = Field(
        default=False,
        description="If true, regenerate even if cached"
    )


# Universal fallback categories - shown immediately before AI loads
UNIVERSAL_USE_CASES = [
    "Work & Productivity",
    "Learning & Research",
    "Communication",
    "Health & Wellness",
    "Entertainment",
    "Organization",
    "Creativity",
    "Finance",
]
