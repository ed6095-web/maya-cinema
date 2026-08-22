"""
MAYA Provider Adapters — Generic Public Provider
Last-resort provider: does a HEAD request to detect if the URL serves video content.
Only accepts publicly accessible, unauthenticated video streams.
"""
import httpx

from .base import MediaSource, ProviderAdapter, ProviderError
from ..utils.url_validation import detect_stream_type

# Content-types that indicate playable media
_PLAYABLE_TYPES = {
    "video/mp4", "video/webm", "video/ogg", "video/quicktime",
    "video/x-matroska", "video/x-msvideo", "video/mp2t",
    "application/x-mpegurl", "application/vnd.apple.mpegurl",
    "application/dash+xml",
}


class GenericPublicProvider(ProviderAdapter):
    """
    Generic fallback provider.

    Attempts a HEAD request on any http/https URL.
    If the server returns a video/* or streaming content-type and the
    resource is publicly accessible (no auth required), MAYA can play it.

    This provider deliberately does NOT:
      - Scrape HTML pages for video URLs
      - Follow JavaScript redirects
      - Bypass access controls
      - Handle DRM-protected content
    """

    @property
    def name(self) -> str:
        return "GenericPublicProvider"

    def can_handle(self, url: str) -> bool:
        return url.lower().startswith(("http://", "https://"))

    async def resolve(self, url: str) -> MediaSource:
        try:
            async with httpx.AsyncClient(
                follow_redirects=True,
                timeout=12.0,
                headers={"User-Agent": "MAYA/1.0 (media-resolver)"},
            ) as client:
                resp = await client.head(url)
        except httpx.RequestError as exc:
            raise ProviderError(
                f"Network error while reaching URL: {exc}",
                "NETWORK_ERROR",
            ) from exc

        if resp.status_code == 401 or resp.status_code == 403:
            raise ProviderError(
                "This media requires authentication or is access-restricted. "
                "MAYA cannot play protected content.",
                "UNSUPPORTED_OR_PROTECTED",
            )

        if resp.status_code == 404:
            raise ProviderError("Media not found (HTTP 404).", "MEDIA_NOT_FOUND")

        if resp.status_code >= 400:
            raise ProviderError(
                f"Server returned HTTP {resp.status_code}. Media may be unavailable.",
                "MEDIA_UNAVAILABLE",
            )

        content_type = resp.headers.get("content-type", "").split(";")[0].strip().lower()
        final_url = str(resp.url)

        stream_type = detect_stream_type(final_url, content_type)

        # Check if content-type explicitly indicates a playable video
        is_video_ct = any(content_type.startswith(t) for t in _PLAYABLE_TYPES)

        if stream_type in ("direct", "hls", "dash") or is_video_ct:
            return MediaSource(
                stream_url=final_url,
                stream_type=stream_type if stream_type != "unknown" else "direct",
                media_type=content_type or "video/mp4",
                provider=self.name,
                source_url=url,
            )

        raise ProviderError(
            f"URL does not point to a publicly accessible video stream. "
            f"Content-type received: '{content_type}'. "
            f"MAYA only supports direct video URLs (MP4, HLS, DASH) and known embed hosts.",
            "UNSUPPORTED_CONTENT_TYPE",
        )
