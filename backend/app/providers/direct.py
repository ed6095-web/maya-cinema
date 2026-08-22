"""
MAYA Provider Adapters — Direct Media
Handles direct media URLs: .mp4, .m3u8, .mpd, .webm etc.
These URLs point directly to a media file and can be played natively.
"""
import httpx
from urllib.parse import urlparse

from .base import MediaSource, ProviderAdapter, ProviderError
from ..utils.url_validation import detect_stream_type

# Extensions that indicate a direct media file
_DIRECT_EXTENSIONS = {
    ".mp4":  "video/mp4",
    ".mkv":  "video/x-matroska",
    ".webm": "video/webm",
    ".mov":  "video/quicktime",
    ".avi":  "video/x-msvideo",
    ".ogv":  "video/ogg",
    ".ts":   "video/mp2t",
}

# Extensions that indicate a streaming manifest
_STREAM_EXTENSIONS = {
    ".m3u8": ("hls",  "application/x-mpegurl"),
    ".mpd":  ("dash", "application/dash+xml"),
}


class DirectMediaProvider(ProviderAdapter):
    """
    Handles direct playable media URLs.

    Identification:
      - URL path ends with a known media extension, OR
      - HTTP HEAD response has a video/* content-type.

    Resolution:
      - Returns the URL as-is (no transformation needed).
      - Verifies the resource is publicly reachable via HEAD request.
    """

    @property
    def name(self) -> str:
        return "DirectMediaProvider"

    def can_handle(self, url: str) -> bool:
        lower = url.lower()
        parsed = urlparse(lower)
        path = parsed.path.split("?")[0]
        for ext in list(_DIRECT_EXTENSIONS) + list(_STREAM_EXTENSIONS):
            if path.endswith(ext):
                return True
        return False

    async def resolve(self, url: str) -> MediaSource:
        lower = url.lower()
        parsed = urlparse(lower)
        path = parsed.path.split("?")[0]

        # Check streaming manifests first
        for ext, (stype, mtype) in _STREAM_EXTENSIONS.items():
            if path.endswith(ext):
                await _verify_reachable(url)
                return MediaSource(
                    stream_url=url,
                    stream_type=stype,
                    media_type=mtype,
                    provider=self.name,
                    source_url=url,
                )

        # Direct video file
        for ext, mtype in _DIRECT_EXTENSIONS.items():
            if path.endswith(ext):
                await _verify_reachable(url)
                return MediaSource(
                    stream_url=url,
                    stream_type="direct",
                    media_type=mtype,
                    provider=self.name,
                    source_url=url,
                )

        raise ProviderError(f"URL does not match any known direct media extension: {url}")


class HeadDetectedProvider(ProviderAdapter):
    """
    Falls back to HEAD-request content-type detection for unknown URLs.
    Handles cases where the URL is a media stream without a file extension.
    """

    @property
    def name(self) -> str:
        return "HeadDetectedProvider"

    def can_handle(self, url: str) -> bool:
        # This is a fallback — accepts any http/https URL
        return url.lower().startswith(("http://", "https://"))

    async def resolve(self, url: str) -> MediaSource:
        try:
            async with httpx.AsyncClient(follow_redirects=True, timeout=10.0) as client:
                resp = await client.head(url, headers={"User-Agent": "MAYA/1.0"})
                content_type = resp.headers.get("content-type", "").lower()
                content_length = resp.headers.get("content-length")
        except httpx.RequestError as exc:
            raise ProviderError(f"Network error reaching URL: {exc}", "NETWORK_ERROR") from exc

        stream_type = detect_stream_type(url, content_type)

        if stream_type in ("direct", "hls", "dash"):
            return MediaSource(
                stream_url=str(resp.url),  # use final URL after redirects
                stream_type=stream_type,
                media_type=content_type or "video/mp4",
                provider=self.name,
                duration=_parse_duration_from_headers(resp.headers),
                source_url=url,
            )

        raise ProviderError(
            f"URL does not appear to be a publicly accessible video stream "
            f"(content-type: '{content_type}').",
            "UNSUPPORTED_CONTENT_TYPE",
        )


def _parse_duration_from_headers(headers) -> int | None:
    """Try to extract duration from X-Content-Duration or similar headers."""
    for key in ("x-content-duration", "x-duration"):
        val = headers.get(key)
        if val:
            try:
                return int(float(val))
            except (ValueError, TypeError):
                pass
    return None


async def _verify_reachable(url: str) -> None:
    """Do a HEAD request to confirm the URL is publicly reachable."""
    try:
        async with httpx.AsyncClient(follow_redirects=True, timeout=8.0) as client:
            resp = await client.head(url, headers={"User-Agent": "MAYA/1.0"})
            if resp.status_code >= 400:
                raise ProviderError(
                    f"Media URL returned HTTP {resp.status_code}.",
                    "MEDIA_UNAVAILABLE",
                )
    except httpx.RequestError as exc:
        raise ProviderError(f"Network error: {exc}", "NETWORK_ERROR") from exc
