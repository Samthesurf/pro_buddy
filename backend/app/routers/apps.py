"""
Apps router.
Handles app use cases caching and retrieval.
"""

import json
from datetime import datetime
from typing import List
from fastapi import APIRouter, Depends, Request, HTTPException

from .auth import get_current_user
from ..models.app_use_cases import (
    AppInfo,
    AppUseCasesRequest,
    AppUseCaseEntry,
    AppUseCasesResponse,
    PopulateRequest,
    UNIVERSAL_USE_CASES,
)
from ..services.usage_store_service import usage_store_service


router = APIRouter()


async def _get_cached_use_cases(package_names: List[str]) -> dict[str, AppUseCaseEntry]:
    """Fetch use cases from D1 cache."""
    if not usage_store_service.configured or not package_names:
        return {}

    try:
        # Query D1 for cached entries
        results = await usage_store_service.get_app_use_cases_bulk(package_names)
        
        cached = {}
        for row in results:
            cached[row["package_name"]] = AppUseCaseEntry(
                package_name=row["package_name"],
                app_name=row["app_name"],
                use_cases=json.loads(row["use_cases"]) if isinstance(row["use_cases"], str) else row["use_cases"],
                category=row.get("category"),
                from_cache=True,
            )
        return cached
    except Exception as e:
        print(f"Error fetching cached use cases: {e}")
        return {}


async def _store_use_cases(entries: List[AppUseCaseEntry]):
    """Store use cases in D1 cache."""
    if not usage_store_service.configured:
        return

    try:
        for entry in entries:
            await usage_store_service.store_app_use_case(
                package_name=entry.package_name,
                app_name=entry.app_name,
                use_cases=entry.use_cases,
                category=entry.category,
            )
    except Exception as e:
        print(f"Error storing use cases: {e}")


@router.post("/use-cases/bulk", response_model=AppUseCasesResponse)
async def get_app_use_cases_bulk(
    request: AppUseCasesRequest,
    req: Request,
    current_user: dict = Depends(get_current_user),
):
    """
    Get use cases for multiple apps.
    
    - Returns cached entries from D1 if available
    - Generates missing entries via Gemini batch call
    - Stores newly generated entries in D1 for future requests
    """
    package_names = [app.package_name for app in request.apps]
    app_lookup = {app.package_name: app.app_name for app in request.apps}
    
    # 1. Check cache
    cached = await _get_cached_use_cases(package_names)
    
    # 2. Find missing
    missing_packages = [p for p in package_names if p not in cached]
    
    results = dict(cached)
    generated_count = 0
    
    # 3. Generate missing via Gemini
    if missing_packages and hasattr(req.app.state, "gemini"):
        gemini = req.app.state.gemini
        
        apps_to_generate = [
            {"app_name": app_lookup[p], "package_name": p}
            for p in missing_packages
        ]
        
        try:
            generated = await gemini.batch_generate_use_cases(apps_to_generate)
            
            new_entries = []
            for package_name, data in generated.items():
                entry = AppUseCaseEntry(
                    package_name=package_name,
                    app_name=app_lookup.get(package_name, package_name),
                    use_cases=data.get("use_cases", []),
                    category=data.get("category"),
                    from_cache=False,
                )
                results[package_name] = entry
                new_entries.append(entry)
                generated_count += 1
            
            # Store in D1 for future requests (fire and forget)
            await _store_use_cases(new_entries)
            
        except Exception as e:
            print(f"Error generating use cases: {e}")
    
    return AppUseCasesResponse(
        results=results,
        cached_count=len(cached),
        generated_count=generated_count,
    )


@router.get("/use-cases/universal")
async def get_universal_use_cases():
    """Get universal fallback use case categories."""
    return {"use_cases": UNIVERSAL_USE_CASES}


@router.post("/use-cases/populate")
async def populate_use_cases(
    request: PopulateRequest,
    req: Request,
    current_user: dict = Depends(get_current_user),
):
    """
    Admin endpoint to pre-populate the database with app use cases.
    
    Used by the population script to batch-fill common apps.
    """
    if not hasattr(req.app.state, "gemini"):
        raise HTTPException(status_code=500, detail="Gemini service not available")
    
    gemini = req.app.state.gemini
    package_names = [app.package_name for app in request.apps]
    app_lookup = {app.package_name: app.app_name for app in request.apps}
    
    # Check what's already cached (unless force_refresh)
    if not request.force_refresh:
        cached = await _get_cached_use_cases(package_names)
        apps_to_generate = [app for app in request.apps if app.package_name not in cached]
    else:
        apps_to_generate = request.apps
        cached = {}
    
    if not apps_to_generate:
        return {
            "success": True,
            "message": "All apps already cached",
            "generated": 0,
            "skipped": len(package_names),
        }
    
    # Generate via Gemini
    generated = await gemini.batch_generate_use_cases([
        {"app_name": app.app_name, "package_name": app.package_name}
        for app in apps_to_generate
    ])
    
    # Store in D1
    new_entries = []
    for package_name, data in generated.items():
        entry = AppUseCaseEntry(
            package_name=package_name,
            app_name=app_lookup.get(package_name, package_name),
            use_cases=data.get("use_cases", []),
            category=data.get("category"),
            from_cache=False,
        )
        new_entries.append(entry)
    
    await _store_use_cases(new_entries)
    
    return {
        "success": True,
        "message": f"Generated use cases for {len(new_entries)} apps",
        "generated": len(new_entries),
        "skipped": len(cached),
    }
