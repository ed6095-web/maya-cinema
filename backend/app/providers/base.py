"""
MAYA Provider Adapters — Base
Abstract base class for all media provider adapters.
"""
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional


@dataclass
class MediaSource:
    """
    Standardised media source returned by any provider adapter.
    Flutter uses this to decide how to play the media.
    """
    stream_url: str
    stream_type: str          # "direct" | "hls" | "dash" | "embed"
    media_type: str           # "video/mp4" | "application/x-mpegurl" | "embed/webview" etc.
    provider: str             # e.g. "DirectMediaProvider"
    title: str = "External Media"
    thumbnail: Optional[str] = None
    duration: Optional[int] = None   # seconds
    expires_at: Optional[datetime] = None
    source_url: str = ""      # original URL supplied by user

    def to_dict(self) -> dict:
        return {
            "success": True,
            "title": self.title,
            "thumbnail": self.thumbnail,
            "duration": self.duration,
            "media_type": self.media_type,
            "stream_type": self.stream_type,
            "stream_url": self.stream_url,
            "provider": self.provider,
            "source_url": self.source_url,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
        }


class ProviderAdapter(ABC):
    """
    Abstract base class for all MAYA media provider adapters.

    Implement can_handle() to return True for URLs this adapter supports.
    Implement resolve() to return a MediaSource for a supported URL.
    """

    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable provider name."""
        ...

    @abstractmethod
    def can_handle(self, url: str) -> bool:
        """Return True if this adapter can attempt to resolve the given URL."""
        ...

    @abstractmethod
    async def resolve(self, url: str) -> MediaSource:
        """
        Resolve the URL into a playable MediaSource.
        Raises ProviderError if resolution fails.
        """
        ...


class ProviderError(Exception):
    """Raised when a provider adapter cannot resolve a URL."""
    def __init__(self, message: str, reason: str = "PROVIDER_ERROR"):
        super().__init__(message)
        self.reason = reason
