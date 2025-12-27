"""
Pro Buddy API - FastAPI Application Entry Point

A goal-tracking backend that monitors app usage and provides
AI-powered feedback using Google Gemini and Cloudflare Vectorize.
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .routers import auth, onboarding, monitor, chat, apps
from .services.cloudflare_service import CloudflareVectorizeService
from .services.gemini_service import GeminiService


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager for startup/shutdown events."""
    # Startup
    print(f"Starting {settings.app_name} v{settings.app_version}")

    # Initialize services
    app.state.vectorize = CloudflareVectorizeService()
    app.state.gemini = GeminiService()

    print("Services initialized successfully")

    yield

    # Shutdown
    print("Shutting down...")


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        description="API for Pro Buddy - Goal-aligned app usage monitoring",
        lifespan=lifespan,
        docs_url="/docs" if settings.debug else None,
        redoc_url="/redoc" if settings.debug else None,
    )

    # Configure CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[],  # Use regex to restrict to localhost with any port
        allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Include routers
    app.include_router(
        auth.router,
        prefix="/api/v1/auth",
        tags=["Authentication"],
    )
    app.include_router(
        onboarding.router,
        prefix="/api/v1/onboarding",
        tags=["Onboarding"],
    )
    app.include_router(
        monitor.router,
        prefix="/api/v1/monitor",
        tags=["Monitoring"],
    )
    app.include_router(
        chat.router,
        prefix="/api/v1/chat",
        tags=["Chat"],
    )
    app.include_router(
        apps.router,
        prefix="/api/v1/apps",
        tags=["Apps"],
    )

    @app.get("/", tags=["Health"])
    async def root():
        """Health check endpoint."""
        return {
            "status": "healthy",
            "app": settings.app_name,
            "version": settings.app_version,
        }

    @app.get("/health", tags=["Health"])
    async def health_check():
        """Detailed health check."""
        return {
            "status": "healthy",
            "services": {
                "cloudflare_vectorize": "configured",
                "gemini": "configured",
                "chat": "configured",
            },
        }

    return app


# Create the application instance
app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )
