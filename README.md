# Pro Buddy

Goal-aligned productivity companion. A Flutter app plus FastAPI backend that:
- Captures your goals and the apps that support them.
- Monitors mobile app usage and flags aligned vs. distracting time.
- Lets you chat with an AI for encouragement, feedback, and summaries.
- Stores context (goals, approved apps, chats) for smarter follow-ups.

## Project Structure
- `lib/`: Flutter app (Firebase Auth + Dio). The polished experience today is the progress chat screen; other routes are placeholders.
- `backend/`: FastAPI service for auth, onboarding, monitoring, and chat.

## How it works (high level)
- Backend (FastAPI): Verifies Firebase tokens, saves goals/apps, analyzes app usage alignment, and powers chat/progress coaching via Google Gemini. Uses Cloudflare Vectorize to remember goals, approved apps, and conversation history. Current storage is in-memory (resets on restart).
- Frontend (Flutter): Firebase Auth bootstrap + Dio client. Progress chat screen loads history, sends daily updates, and renders AI replies. Other flows (onboarding, dashboard, settings) are scaffolded but not fully built.

## Quick start — Backend
1) Python 3.11+. From `backend/`:
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```
2) Add a `.env` with your keys: `GEMINI_API_KEY`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN`, optional `DEBUG=true`, and `FIREBASE_CREDENTIALS_PATH` for real auth (dev fallback returns a mock user).
3) Run:
```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
Docs live at `/docs` when `DEBUG=true`. API base path is `/api/v1`.

## Quick start — Flutter app
1) Flutter SDK ^3.10 and a Firebase project. Add `google-services.json` / `GoogleService-Info.plist` as usual.
2) Set the backend URL in `lib/core/constants.dart` if not using the default emulator value `http://10.0.2.2:8000/api/v1`.
3) Install and run:
```bash
flutter pub get
flutter run
```

## Current status / notes
- Data is in-memory today (clears on backend restart). Plan to add a real database.
- AI and embeddings need valid Gemini + Cloudflare credentials; otherwise responses fall back to defaults or fail.
- Mobile background monitoring is scaffolded; platform permissions/services still need to be wired up for a production build.
