"""
MAYA Provider Adapters — Embed Hosts
Handles video embed hosts (Streamtape, MixDrop, Doodstream, Streamwish, etc.)
These hosts provide embed pages designed for in-app embedding via WebView.
The URL is converted to the embed form and returned for WebView playback.
"""
from urllib.parse import urlparse

from .base import MediaSource, ProviderAdapter, ProviderError

# Map of hostname fragments → (canonical_name, embed_path_prefix)
# The embed_path_prefix is what the /e/ segment is for that host.
_EMBED_HOSTS: dict[str, str] = {
    # Streamtape
    "streamtape.com":  "streamtape",
    "streamtape.to":   "streamtape",
    "streamtape.net":  "streamtape",
    "streamtape.xyz":  "streamtape",
    # Doodstream
    "doodstream.com":  "doodstream",
    "dood.watch":      "doodstream",
    "dood.to":         "doodstream",
    "dood.so":         "doodstream",
    "dood.la":         "doodstream",
    "dood.pm":         "doodstream",
    "d0000d.com":      "doodstream",
    # Streamwish
    "streamwish.com":  "streamwish",
    "streamwish.to":   "streamwish",
    "streamwish.net":  "streamwish",
    # FileMoon
    "filemoon.sx":     "filemoon",
    "filemoon.to":     "filemoon",
    "filemoon.in":     "filemoon",
    # StreamVid
    "streamvid.net":   "streamvid",
    # VidMoly
    "vidmoly.to":      "vidmoly",
    "vidmoly.me":      "vidmoly",
    # VidHide
    "vidhide.com":     "vidhide",
    "vidhide.to":      "vidhide",
    "streamhide.com":  "vidhide",
    # VidSrc
    "vidsrc.to":       "vidsrc",
    "vidsrc.me":       "vidsrc",
    "vidsrc.xyz":      "vidsrc",
    "vidsrc.net":      "vidsrc",
    "vidsrc.cc":       "vidsrc",
    "vidsrc.vip":      "vidsrc",
    # VidCloud
    "vidcloud.co":     "vidcloud",
    "vidcloud9.com":   "vidcloud",
    # RapidVideo
    "rapidvideo.com":  "rapidvideo",
    # Upstream
    "upstream.to":     "upstream",
    # MixDrop
    "mixdrop.co":      "mixdrop",
    "mixdrop.to":      "mixdrop",
    "mixdrop.bz":      "mixdrop",
    "mixdrop.top":     "mixdrop",
    "mixdrop.ag":      "mixdrop",
    "mixdrop.ch":      "mixdrop",
    "mixdrop.gl":      "mixdrop",
    "mixdrop.club":    "mixdrop",
    # Streamlare
    "streamlare.com":  "streamlare",
    "streamlare.net":  "streamlare",
    # fembed
    "fembed.com":      "fembed",
    # Google Drive
    "drive.google.com": "googledrive",
}


class EmbedHostProvider(ProviderAdapter):
    """
    Handles known video embed hosts.

    These services are designed to be embedded in third-party applications.
    Their embed pages show only the video player (no website chrome).
    Flutter loads the embed URL in a WebView.

    URL normalisation:
      /v/ID  →  /e/ID   (for most hosts)
      /f/ID  →  /e/ID   (for MixDrop, Doodstream)
    """

    @property
    def name(self) -> str:
        return "EmbedHostProvider"

    def can_handle(self, url: str) -> bool:
        hostname = _get_hostname(url)
        return hostname in _EMBED_HOSTS

    async def resolve(self, url: str) -> MediaSource:
        hostname = _get_hostname(url)
        canonical = _EMBED_HOSTS.get(hostname)

        if canonical is None:
            raise ProviderError(f"Host '{hostname}' not in embed host registry.")

        # Google Drive special handling
        if canonical == "googledrive":
            file_id = _extract_drive_id(url)
            if not file_id:
                raise ProviderError("Could not extract Google Drive file ID from URL.")
            stream_url = (
                f"https://drive.usercontent.google.com/download"
                f"?id={file_id}&export=download&authuser=0&confirm=t"
            )
            return MediaSource(
                stream_url=stream_url,
                stream_type="direct",
                media_type="video/mp4",
                provider=self.name,
                title="Google Drive Video",
                source_url=url,
            )

        embed_url = _to_embed_url(url, canonical)
        return MediaSource(
            stream_url=embed_url,
            stream_type="embed",
            media_type="embed/webview",
            provider=f"EmbedHostProvider/{canonical}",
            title=f"{canonical.title()} Video",
            source_url=url,
        )


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _get_hostname(url: str) -> str:
    try:
        return urlparse(url.lower()).hostname or ""
    except Exception:
        return ""


def _to_embed_url(url: str, canonical: str) -> str:
    """Convert a host-specific URL to its embed form."""
    # Already an embed URL (/e/ path segment)
    if "/e/" in url:
        return url

    replacements = [("/v/", "/e/"), ("/f/", "/e/"), ("/video/", "/e/"),
                    ("/file/", "/e/"), ("/stream/", "/e/"), ("/d/", "/e/")]

    for src, dst in replacements:
        if src in url:
            return url.replace(src, dst, 1)

    return url  # Return as-is if no pattern matched


def _extract_drive_id(url: str) -> str | None:
    """Extract Google Drive file ID from share URLs."""
    import re
    # /file/d/FILE_ID/
    m = re.search(r"/file/d/([a-zA-Z0-9_-]{20,})", url)
    if m:
        return m.group(1)
    # ?id=FILE_ID or &id=FILE_ID
    m = re.search(r"[?&]id=([a-zA-Z0-9_-]{20,})", url)
    if m:
        return m.group(1)
    return None
