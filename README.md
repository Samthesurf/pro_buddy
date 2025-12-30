# Pro Buddy

Goal-aligned productivity companion. A Flutter app plus FastAPI backend that helps you stay focused on what matters.

## Key Features
- **Goal Discovery:** Interactive chat interface to help you articulate and refine your productivity goals.
- **Smart Dashboard:** "Cozy" styled dashboard that shows your focus score, streak, and daily alignment.
- **App Alignment:** Categorizes your app usage as "Focused", "Break", or "Distracted" based on your goals.
- **AI Coaching:** Chat with an AI companion for encouragement, feedback, and daily summaries.
- **Usage Monitoring:** Tracks screen time and specific app usage to provide actionable insights.

## Project Structure
- `lib/`: Flutter application using Bloc for state management.
    - `screens/`: Fully implemented screens include Auth, Goal Discovery, App Selection, and the Main Dashboard.
    - `bloc/`: Business logic for goals, usage tracking, and chat.
- `backend/`: FastAPI service.
    - Handles authentication (Firebase).
    - Manages user goals and app categorization.
    - Powers the AI chat using Google Gemini.
    - Uses Cloudflare Vectorize for semantic understanding of goals.
- `conductor/`: Project management and architectural documentation.

## Getting Started

### Backend Setup
1.  **Prerequisites:** Python 3.11+
2.  **Environment:**
    Create a `.env` file in the `backend/` directory based on `backend/env.example`. You will need:
    -   `GEMINI_API_KEY`: For AI features.
    -   `CLOUDFLARE_ACCOUNT_ID` & `CLOUDFLARE_API_TOKEN`: For vector embeddings.
    -   `FIREBASE_CREDENTIALS_PATH`: Path to your Firebase Admin SDK JSON file.
3.  **Install & Run:**
    ```bash
    cd backend
    python -m venv .venv
    source .venv/bin/activate  # or .venv\Scripts\activate on Windows
    pip install -r requirements.txt
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
    ```
    API documentation is available at `http://localhost:8000/docs` when `DEBUG=true`.

### Mobile App Setup
1.  **Prerequisites:** Flutter SDK ^3.10
2.  **Firebase:**
    -   Create a Firebase project.
    -   Add `google-services.json` to `android/app/`.
    -   Add `GoogleService-Info.plist` to `ios/Runner/`.
3.  **Configuration:**
    -   Update `lib/core/constants.dart` if your backend URL differs from the default (e.g., for physical devices).
4.  **Run:**
    ```bash
    flutter pub get
    flutter run
    ```

## Current Status
-   **Frontend:** Core flows (Onboarding, Goal Discovery, Dashboard) are implemented and functional. Usage history and settings are currently placeholders.
-   **Backend:** Fully functional for the implemented frontend features.
-   **Persistence:** Currently using in-memory storage for some features.
    -   **Active Track:** Moving to persistent storage using Cloudflare D1 (see `conductor/tracks/d1_persistence_20251220/`).

## Deployment
The backend is currently deployed on **Oracle Cloud Always Free** tier.

**Stack:**
-   **Runtime:** Docker (running the FastAPI app).
-   **Reverse Proxy:** Caddy (handles HTTPS and reverse proxying).
-   **Domain:** sslip.io (for DNS resolution to the instance IP).
-   **Access:** SSH.

For setup details or replication, refer to `backend/DEPLOY_ORACLE.md`.