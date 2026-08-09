# MAYA — Stream Resolver Router
# Provides the /api/resolve/stream endpoint which takes any cloud storage URL
# (Diskwala, TeraBox, etc.) and returns a direct playable stream URL via
# headless browser interception. The Flutter app calls this before playing.

import logging
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

log = logging.getLogger(__name__)

router = APIRouter(prefix="/api/resolve", tags=["stream-resolver"])


class ResolveRequest(BaseModel):
    url: str


class ResolveResponse(BaseModel):
    stream_url: str
    source: str
    original_url: str


@router.post("/stream", response_model=ResolveResponse)
async def resolve_stream(request: ResolveRequest):
    """
    Resolve a cloud storage share URL to a direct playable stream URL.
    Supports: Diskwala (diskwala.com/app/...)
    The resolved URL can be played directly in MAYA's native video player.
    """
    url = request.url.strip()

    if not url:
        raise HTTPException(status_code=400, detail="URL is required")

    # Diskwala resolution
    if "diskwala.com" in url.lower():
        log.info(f"Resolving Diskwala URL: {url}")
        from app.services.diskwala_resolver import resolve_diskwala_stream
        stream_url = await resolve_diskwala_stream(url)
        if stream_url:
            return ResolveResponse(
                stream_url=stream_url,
                source="diskwala",
                original_url=url,
            )
        else:
            raise HTTPException(
                status_code=422,
                detail="Could not resolve stream URL from Diskwala. The link may have expired or be private."
            )

    # If it's already a direct media URL, return it as-is
    direct_extensions = [".mp4", ".mkv", ".avi", ".m3u8", ".ts", ".webm", ".mov"]
    if any(url.lower().endswith(ext) or ext + "?" in url.lower() for ext in direct_extensions):
        return ResolveResponse(
            stream_url=url,
            source="direct",
            original_url=url,
        )

    # For unrecognized URLs, return as-is for WebView fallback
    return ResolveResponse(
        stream_url=url,
        source="unknown",
        original_url=url,
    )


@router.get("/health")
async def resolver_health():
    """Check if playwright is installed and functional."""
    try:
        import playwright
        return {"status": "ok", "playwright": "installed"}
    except ImportError:
        return {"status": "degraded", "playwright": "not installed"}
