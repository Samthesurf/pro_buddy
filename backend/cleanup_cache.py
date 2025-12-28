#!/usr/bin/env python3
"""
Cleanup script for removing poisoned cache entries (empty app use cases).

This script directly calls the Cloudflare worker to clean up app use cases
that have empty use_cases arrays, which can happen when Gemini API calls fail.
"""

import asyncio
import httpx
import os
from pathlib import Path
from dotenv import load_dotenv


async def main():
    """Clean up poisoned cache entries."""
    # Load environment variables
    env_path = Path(__file__).parent / ".env"
    load_dotenv(env_path)
    
    worker_url = os.getenv("USAGE_STORE_WORKER_URL")
    worker_token = os.getenv("USAGE_STORE_WORKER_TOKEN")
    
    print("🧹 Cleaning up poisoned cache entries...")
    print(f"Worker URL: {worker_url}")
    
    if not worker_url or not worker_token:
        print("❌ Error: Worker credentials not found!")
        print("Make sure USAGE_STORE_WORKER_URL and USAGE_STORE_WORKER_TOKEN are set in .env")
        return 1
    
    try:
        headers = {"X-ProBuddy-Worker-Token": worker_token}
        url = f"{worker_url.rstrip('/')}/v1/app-use-cases/cleanup"
        
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.request("DELETE", url, headers=headers)
            response.raise_for_status()
            result = response.json()
        
        print(f"\n✅ Success!")
        print(f"   Deleted: {result.get('deleted_count', 0)} poisoned entries")
        print(f"   Message: {result.get('message', 'Cleanup completed')}")
        return 0
        
    except httpx.HTTPStatusError as e:
        print(f"\n❌ HTTP Error: {e.response.status_code}")
        print(f"   Response: {e.response.text}")
        return 1
    except Exception as e:
        print(f"\n❌ Error during cleanup: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    exit(exit_code)
