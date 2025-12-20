# Technology Stack

## Frontend (Mobile App)
- **Framework:** Flutter (v3.10.1+)
- **State Management:** `flutter_bloc` (Cubit/Bloc)
- **Networking:** `dio` for REST API communication.
- **Authentication:** Firebase Authentication (with `firebase_auth`, `google_sign_in`).
- **Local Storage:** `shared_preferences`, `flutter_secure_storage`.
- **UI Components:** `google_fonts`, `lottie`, `flutter_svg`, `shimmer`.
- **Utilities:** `workmanager` for background tasks, `flutter_local_notifications`.

## Backend (API Service)
- **Framework:** FastAPI (Python 3.11+)
- **Server:** Uvicorn
- **AI/LLM:** `google-genai` (Gemini API)
- **Authentication (Admin):** `firebase-admin` for token verification.
- **Data Validation:** `pydantic` (v2)
- **HTTP Client:** `httpx`

## Data & Memory
- **Database:** In-memory (Current), Migration to a persistent database (Planned).
- **Vector Database:** Cloudflare Vectorize for storing and retrieving goal/app context and chat embeddings.

## Infrastructure & DevOps
- **Containerization:** Docker (Dockerfile & `docker-compose.yml`)
- **API Documentation:** OpenAPI (Swagger) via FastAPI `/docs`.
