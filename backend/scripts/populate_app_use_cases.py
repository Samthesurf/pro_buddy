#!/usr/bin/env python3
"""
Populate App Use Cases Database

This script pre-fills the D1 database with common app use cases via Gemini,
so that new users don't have to wait for AI generation during onboarding.

Usage:
    cd backend
    python scripts/populate_app_use_cases.py [--dry-run]
"""

import asyncio
import argparse
import sys
import os

# Add parent to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.gemini_service import GeminiService
from app.services.usage_store_service import usage_store_service


import random

# Diverse pool of categories to ensure variety across runs
CATEGORY_POOL = [
    "Productivity", "Note-taking", "Project Management", "Time Tracking", 
    "Focus & Meditation", "Fitness & Health", "Budgeting & Finance",
    "Learning & Education", "Reading & Books", "News & Magazines",
    "Social Media", "Communication", "Video Conferencing", "Email Clients",
    "Calendar & Scheduling", "Cloud Storage", "File Management",
    "Password Managers", "VPN & Security", "Browsers",
    "Music Streaming", "Podcast Players", "Video Streaming", "Photo Editing",
    "Vector Design", "Code Editors", "Developer Tools", "AI & Utilities",
    "Travel & Maps", "Food & Drink", "Shopping", "Lifestyle",
    "Parenting", "Dating", "Weather", "Sports", "Gaming",
    "Business", "Medical", "Real Estate", "Auto & Vehicles"
]


async def main():
    parser = argparse.ArgumentParser(description="Populate app use cases database")
    parser.add_argument("--dry-run", action="store_true", help="Print apps without making API calls")
    parser.add_argument("--limit", type=int, default=100, help="Target number of fresh apps to find (default: 100)")
    args = parser.parse_args()

    if not usage_store_service.configured:
        print("ERROR: UsageStoreService is not configured. Check USAGE_STORE_WORKER_URL and USAGE_STORE_WORKER_TOKEN.")
        sys.exit(1)

    gemini = GeminiService()
    
    # We want to find `args.limit` FRESH apps.
    # We'll stick to a loop where we pick random categories, generate apps, check cache, and keep the fresh ones.
    
    fresh_apps_to_process = []
    attempt = 0
    max_attempts = 5
    
    # Track what we've tried to avoid repeating in one run
    used_categories = set()
    
    print(f"Goal: Find {args.limit} FRESH apps (not already in DB).")
    
    while len(fresh_apps_to_process) < args.limit and attempt < max_attempts:
        attempt += 1
        
        # Pick random categories
        available_cats = [c for c in CATEGORY_POOL if c not in used_categories]
        if not available_cats:
            print(" exhausted all categories.")
            break
            
        # Pick 5 categories per attempt
        current_cats = random.sample(available_cats, min(5, len(available_cats)))
        used_categories.update(current_cats)
        
        print(f"\n[Attempt {attempt}/{max_attempts}] Querying Gemini for apps in: {', '.join(current_cats)}...")
        
        # Ask Gemini for apps (~20 per category to get a good batch)
        # We ask for a bit more than we need because many will be duplicates or cached
        generated_apps = await gemini.generate_app_list(current_cats, count_per_category=15)
        
        if not generated_apps:
            print("  No apps returned from Gemini. Retrying...")
            continue
            
        print(f"  Generated {len(generated_apps)} candidates.")
        
        # Deduplicate candidates (within this run)
        unique_candidates = {app['package_name']: app for app in generated_apps}.values()
        
        # Check cache for these candidates
        package_names = [app["package_name"] for app in unique_candidates]
        cached_packages = set()
        
        # Batch cache checks
        BATCH_SIZE = 100
        try:
            for i in range(0, len(package_names), BATCH_SIZE):
                batch = package_names[i:i + BATCH_SIZE]
                cached_batch = await usage_store_service.get_app_use_cases_bulk(batch)
                for item in cached_batch:
                    cached_packages.add(item["package_name"])
        except Exception as e:
            print(f"  Warning: Could not check cache: {e}")
            
        # Filter to truly fresh apps
        batch_fresh = [
            app for app in unique_candidates 
            if app["package_name"] not in cached_packages 
            and app["package_name"] not in {a["package_name"] for a in fresh_apps_to_process}
        ]
        
        print(f"  Found {len(batch_fresh)} NEW apps not in DB.")
        fresh_apps_to_process.extend(batch_fresh)
        
        if len(fresh_apps_to_process) >= args.limit:
            break

    # Trim to limit
    fresh_apps_to_process = fresh_apps_to_process[:args.limit]

    if not fresh_apps_to_process:
        print("\nCould not find any new apps after multiple attempts. detailed database or AI limitation.")
        return

    print(f"\nProcessing {len(fresh_apps_to_process)} fresh apps...")
    
    if args.dry_run:
        print("DRY RUN - Would populate use cases for these apps:")
        for app in fresh_apps_to_process:
            print(f"  - {app['app_name']} ({app['package_name']})")
        return

    # Generate use cases in batches
    # Note: 'category' might be present from generate_app_list, logic in GeminiService.batch_generate_use_cases 
    # might overwrite it or use it. The batch generator usually ignores input category and rediscovers it,
    # but that's fine.
    
    print("Generating use cases via Gemini...")
    try:
        results = await gemini.batch_generate_use_cases(fresh_apps_to_process)
    except Exception as e:
        print(f"ERROR generating use cases: {e}")
        sys.exit(1)

    # Store results
    success_count = 0
    for app in fresh_apps_to_process:
        pkg = app["package_name"]
        if pkg in results:
            data = results[pkg]
            use_cases = data.get("use_cases", [])
            
            if not use_cases:
                print(f"WRN {app['app_name']}: Generated empty use cases. Skipping.")
                continue
                
            try:
                await usage_store_service.store_app_use_case(
                    package_name=pkg,
                    app_name=app["app_name"],
                    use_cases=use_cases,
                    category=data.get("category"),
                )
                print(f"✓ {app['app_name']}: {use_cases}")
                success_count += 1
            except Exception as e:
                print(f"✗ {app['app_name']}: Failed to store - {e}")
        else:
            print(f"? {app['app_name']}: No results returned")

    print(f"\nDone! Successfully populated {success_count}/{len(fresh_apps_to_process)} apps.")


if __name__ == "__main__":
    asyncio.run(main())
