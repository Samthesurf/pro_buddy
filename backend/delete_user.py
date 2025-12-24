import asyncio
import sys
import os

# Add backend directory to path so we can import app modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.services.auth_service import auth_service
from app.services.usage_store_service import usage_store_service
from app.services.cloudflare_service import CloudflareVectorizeService
from firebase_admin import auth

async def main():
    print("=== Pro Buddy User Deletion Script ===")
    print("This script will delete user data from:")
    print("1. Firebase Authentication (Account)")
    print("2. Cloudflare D1 (Usage Store)")
    print("3. Cloudflare Vectorize (Embeddings/RAG)")
    print("========================================")

    target = input("\nEnter User ID or Email: ").strip()
    if not target:
        print("No input provided. Exiting.")
        return

    uid = target
    email = None

    # Check if input looks like an email
    if "@" in target:
        try:
            print(f"Looking up user by email: {target}...")
            # We access auth directly or via auth_service if exposed, but auth_service
            # doesn't expose get_user_by_email easily. accessing firebase_admin.auth directly.
            # However, auth_service initializes the app, which is required.
            # Assuming auth_service is instantiated at import time (which it is).
            user = auth.get_user_by_email(target)
            uid = user.uid
            email = user.email
            print(f"Found User ID: {uid}")
        except Exception as e:
            print(f"Error finding user by email: {e}")
            return

    # Confirm deletion
    print(f"\nTarget: {uid} ({email or 'No Email'})")
    delete_auth = input("Delete Firebase Auth Account as well? (y/N): ").strip().lower() == 'y'
    
    msg = "This will DELETE ALL USER DATA from Cloudflare."
    if delete_auth:
        msg += " AND DELETE the Firebase Auth account."
    else:
        msg += " The Firebase account will be preserved (Reset)."
        
    print(f"\nWARNING: {msg}")
    confirm = input("Type 'DELETE' to confirm: ").strip()
    if confirm != "DELETE":
        print("Confirmation failed. Exiting.")
        return

    print("\nStarting deletion process...")

    # 1. Cloudflare Vectorize
    print("1. Deleting from Cloudflare Vectorize...", end=" ", flush=True)
    try:
        vectorize = CloudflareVectorizeService()
        await vectorize.delete_user_data(uid)
        print("Done.")
    except Exception as e:
        print(f"Failed: {e}")

    # 2. Cloudflare D1 (Usage Store)
    print("2. Deleting from Usage Store (D1)...", end=" ", flush=True)
    try:
        await usage_store_service.delete_user_data(uid)
        print("Done.")
    except Exception as e:
        print(f"Failed: {e}")

    # 3. Firebase Auth
    if delete_auth:
        print("3. Deleting from Firebase Auth...", end=" ", flush=True)
        try:
            success = auth_service.delete_user(uid)
            if success:
                print("Done.")
            else:
                print("Failed (or user not found).")
        except Exception as e:
            print(f"Failed: {e}")
    else:
        print("3. Firebase Auth account preserved.")

    print("\nDeletion complete.")

if __name__ == "__main__":
    asyncio.run(main())
