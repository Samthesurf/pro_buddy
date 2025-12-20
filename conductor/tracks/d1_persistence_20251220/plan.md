# Implementation Plan - Implement Persistent Storage with Cloudflare D1

## Phase 1: Research & Configuration
- [ ] Task: Research FastAPI and Cloudflare D1 integration patterns. Determine if we use the HTTP API or if a specific Python client exists.
- [ ] Task: Set up Cloudflare D1 database instance and configure API credentials/tokens in `.env`.
- [ ] Task: Update `tech-stack.md` to reflect the addition of Cloudflare D1.
- [ ] Task: Conductor - User Manual Verification 'Research & Configuration' (Protocol in workflow.md)

## Phase 2: Schema Design & Migration
- [ ] Task: Define SQL schema for `users` table.
- [ ] Task: Define SQL schema for `goals` table.
- [ ] Task: Define SQL schema for `apps` (whitelisted apps) table.
- [ ] Task: Create a migration script or initialization logic to apply these schemas to the D1 database.
- [ ] Task: Conductor - User Manual Verification 'Schema Design & Migration' (Protocol in workflow.md)

## Phase 3: Backend Integration (Refactoring)
- [ ] Task: Create a database connection/client module in `backend/app/` to handle D1 interactions.
- [ ] Task: Refactor `User` model and related endpoints to use D1.
    - [ ] Sub-task: Write Tests for User persistence.
    - [ ] Sub-task: Implement User D1 integration.
- [ ] Task: Refactor `Goal` model and related endpoints to use D1.
    - [ ] Sub-task: Write Tests for Goal persistence.
    - [ ] Sub-task: Implement Goal D1 integration.
- [ ] Task: Refactor `App` (Whitelist) model and related endpoints to use D1.
    - [ ] Sub-task: Write Tests for App persistence.
    - [ ] Sub-task: Implement App D1 integration.
- [ ] Task: Conductor - User Manual Verification 'Backend Integration' (Protocol in workflow.md)

## Phase 4: Verification & Cleanup
- [ ] Task: Run full integration tests to ensure data persists across "restarts" (mocked or actual).
- [ ] Task: Remove old in-memory storage code.
- [ ] Task: Update `README.md` with new setup instructions for D1.
- [ ] Task: Conductor - User Manual Verification 'Verification & Cleanup' (Protocol in workflow.md)
