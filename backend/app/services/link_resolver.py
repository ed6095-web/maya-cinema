"""
MAYA — Link Resolver Service
Orchestrates URL validation → provider selection → resolution → standardised response.
"""
import logging
from typing import Optional

from ..providers import (
    DirectMediaProvider,
    EmbedHostProvider,
    GenericPublicProvider,
    HeadDetectedProvider,
    MediaSource,
    ProviderAdapter,
    ProviderError,
)
from ..utils.url_validation import URLValidationError, validate_url

logger = logging.getLogger(__name__)

# Ordered list of provider adapters.
# Providers are tried in order; the first that can_handle() wins.
_PROVIDERS: list[ProviderAdapter] = [
    EmbedHostProvider(),       # Known embed hosts (MixDrop, Streamtape, Drive, etc.)
    DirectMediaProvider(),     # Direct .mp4 / .m3u8 / .mpd URLs
    HeadDetectedProvider(),    # HEAD content-type detection for direct streams
    GenericPublicProvider(),   # Generic fallback
]


class LinkResolverResult:
    """Result returned by the link resolver to the API layer."""

    def __init__(
        self,
        success: bool,
        media_source: Optional[MediaSource] = None,
        error: Optional[str] = None,
        error_code: Optional[str] = None,
    ):
        self.success = success
        self.media_source = media_source
        self.error = error
        self.error_code = error_code

    def to_dict(self) -> dict:
        if self.success and self.media_source:
            return self.media_source.to_dict()
        return {
            "success": False,
            "error": self.error or "Unable to resolve media.",
            "error_code": self.error_code or "RESOLUTION_FAILED",
        }


async def resolve_link(url: str) -> LinkResolverResult:
    """
    Main entry point for link resolution.

    Steps:
      1. Validate & sanitise the URL (SSRF protection).
      2. Normalise the URL.
      3. Find a provider that can handle the URL.
      4. Attempt resolution.
      5. Return a standardised LinkResolverResult.

    Never raises exceptions — always returns a result.
    """
    # ── Step 1: URL Validation ────────────────────────────────────────────
    try:
        validated_url = validate_url(url)
    except URLValidationError as exc:
        logger.warning("URL validation failed for '%s': %s", url, exc)
        return LinkResolverResult(
            success=False,
            error=str(exc),
            error_code="INVALID_URL",
        )

    # ── Step 2: Provider Selection & Resolution ───────────────────────────
    for provider in _PROVIDERS:
        if not provider.can_handle(validated_url):
            continue

        logger.info("Trying provider '%s' for URL: %s", provider.name, validated_url)
        try:
            media_source = await provider.resolve(validated_url)
            logger.info(
                "Resolved via '%s': stream_type=%s url=%s",
                provider.name,
                media_source.stream_type,
                media_source.stream_url[:80],
            )
            return LinkResolverResult(success=True, media_source=media_source)

        except ProviderError as exc:
            logger.info(
                "Provider '%s' failed (%s): %s",
                provider.name, exc.reason, exc,
            )
            # If it's a protection/auth error, stop immediately
            if exc.reason in ("UNSUPPORTED_OR_PROTECTED", "MEDIA_NOT_FOUND"):
                return LinkResolverResult(
                    success=False,
                    error=str(exc),
                    error_code=exc.reason,
                )
            # Otherwise try next provider
            continue

        except Exception as exc:
            logger.exception("Unexpected error in provider '%s': %s", provider.name, exc)
            continue

    return LinkResolverResult(
        success=False,
        error=(
            "Unable to play this link. "
            "MAYA supports direct MP4/HLS URLs and known embed hosts (MixDrop, Streamtape, etc.). "
            "Unsupported or protected content cannot be played."
        ),
        error_code="UNSUPPORTED_URL",
    )
