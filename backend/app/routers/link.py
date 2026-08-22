"""MAYA — Link Player Router: POST /api/link/resolve"""
import logging
from fastapi import APIRouter, HTTPException

from ..schemas.link import LinkResolveRequest, LinkResolveResponse
from ..services.link_resolver import resolve_link

router = APIRouter(prefix="/api/link", tags=["link"])
logger = logging.getLogger(__name__)


@router.post("/resolve", response_model=LinkResolveResponse)
async def resolve_media_link(request: LinkResolveRequest):
    """
    Resolve a user-supplied URL into a playable media source.

    Accepts:
      - Direct MP4/MKV/WebM URLs
      - HLS (.m3u8) stream URLs
      - DASH (.mpd) manifest URLs
      - Known embed host URLs (MixDrop, Streamtape, Doodstream, etc.)
      - Google Drive share links

    Does NOT:
      - Bypass DRM or authentication
      - Scrape protected content
      - Access private/internal network addresses (SSRF protected)
    """
    logger.info("Link resolve request for: %s", request.url[:100])
    result = await resolve_link(request.url)
    return LinkResolveResponse(**result.to_dict())
