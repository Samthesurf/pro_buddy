# Track Specification: Implement Persistent Storage with Cloudflare D1

## Overview
This track involves migrating the backend's data storage from in-memory structures to Cloudflare D1, a serverless SQL database. This ensures that critical user data—specifically user profiles, defined goals, and whitelisted apps—is persisted reliably across server restarts and deployments.

## Goals
- **Data Persistence:** Eliminate data loss on server restart by moving state to Cloudflare D1.
- **Schema Definition:** Define clear SQL schemas for Users, Goals, and App Whitelists.
- **Backend Integration:** Update the FastAPI backend to interact with D1 for CRUD operations.
- **Performance:** Ensure low-latency data access suitable for real-time app usage monitoring.

## Key Features
1.  **Database Setup:** Configuration of Cloudflare D1 database and bindings.
2.  **Schema Migration:** Creation of tables for:
    -   `users`: ID, email, preferences.
    -   `goals`: ID, user_id, title, description, status.
    -   `apps`: ID, user_id, package_name, is_whitelisted.
3.  **API Update:** Refactor existing endpoints in `backend/app/routers/` to read/write from D1 instead of memory.
4.  **Testing:** Unit and integration tests to verify data persistence and retrieval.

## Technical Considerations
-   **Cloudflare Workers/Pages:** D1 is typically accessed via Cloudflare Workers. We need to ensure the FastAPI app (likely running on a standard server/container) can access D1, or we might need to adapt the deployment architecture to use Cloudflare Workers or use the D1 HTTP API if applicable. *Note: Given the existing Docker setup, we will assume usage of the D1 HTTP API or a compatible client library for Python if available, or investigate the best path for FastAPI <-> D1 connectivity.*
-   **Authentication:** Ensure secure connection to the D1 instance.

## Success Metrics
-   User data (goals, settings) survives a backend service restart.
-   API endpoints return consistent data after storage migration.
-   No regression in API response times.
