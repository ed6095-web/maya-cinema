"""
MAYA Backend — FastAPI Application Entry Point
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from pathlib import Path

from app.core.config import settings
from app.core.database import init_db

# Import all models so SQLAlchemy registers them before create_all
from app.models import user, movie, favorite, watch_history, external_media  # noqa: F401

from app.routers import auth, movies, favorites, watch, genres, admin, stream_resolver, link, external


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Run startup tasks: initialize database tables."""
    await init_db()
    yield


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="MAYA — Personal Movie Streaming Platform API",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# ---------------------------------------------------------------------------
# CORS Middleware
# ---------------------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Range", "Accept-Ranges", "Content-Length"],
)

# ---------------------------------------------------------------------------
# Routers
# ---------------------------------------------------------------------------
app.include_router(auth.router)
app.include_router(movies.router)
app.include_router(favorites.router)
app.include_router(watch.router)
app.include_router(genres.router)
app.include_router(admin.router)
app.include_router(stream_resolver.router)
app.include_router(link.router)
app.include_router(external.router)


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------
@app.get("/api/health", tags=["Health"])
async def health_check():
    """Backend health check endpoint. Used by Flutter to verify connectivity."""
    return JSONResponse(
        content={
            "status": "ok",
            "app": settings.app_name,
            "version": settings.app_version,
        }
    )


@app.get("/apk", tags=["Download"])
async def download_apk():
    """Directly download the compiled Android APK to your phone over Wi-Fi."""
    apk_path = Path(__file__).parents[2] / "frontend" / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    if not apk_path.exists():
        return JSONResponse(status_code=404, content={"error": "APK not found"})
    return FileResponse(
        path=str(apk_path),
        media_type="application/vnd.android.package-archive",
        filename="MAYA.apk",
    )


# ---------------------------------------------------------------------------
# Serve Flutter Web App (Static SPA)
# ---------------------------------------------------------------------------
web_dir = Path(__file__).parents[2] / "frontend" / "build" / "web"
if web_dir.exists():
    from fastapi.staticfiles import StaticFiles
    app.mount("/", StaticFiles(directory=str(web_dir), html=True), name="web")
else:
    @app.get("/", tags=["Root"])
    async def root():
        return {"message": f"Welcome to {settings.app_name} API. Visit /docs for documentation."}

