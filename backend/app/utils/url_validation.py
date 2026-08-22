"""
MAYA — URL Validation & SSRF Protection
Validates that a user-supplied URL is safe to request from the backend.
"""
import ipaddress
import re
import socket
from urllib.parse import urlparse


# Private/reserved IPv4 networks (SSRF blocklist)
_PRIVATE_NETWORKS = [
    ipaddress.ip_network("0.0.0.0/8"),
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("100.64.0.0/10"),
    ipaddress.ip_network("127.0.0.0/8"),
    ipaddress.ip_network("169.254.0.0/16"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.0.0.0/24"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("198.18.0.0/15"),
    ipaddress.ip_network("198.51.100.0/24"),
    ipaddress.ip_network("203.0.113.0/24"),
    ipaddress.ip_network("224.0.0.0/4"),
    ipaddress.ip_network("240.0.0.0/4"),
    ipaddress.ip_network("255.255.255.255/32"),
]

_PRIVATE_V6 = [
    ipaddress.ip_network("::1/128"),
    ipaddress.ip_network("fc00::/7"),
    ipaddress.ip_network("fe80::/10"),
    ipaddress.ip_network("::ffff:0:0/96"),
]

_BLOCKED_HOSTNAMES = {
    "localhost",
    "metadata.google.internal",
    "169.254.169.254",  # AWS metadata
}

_ALLOWED_SCHEMES = {"http", "https"}


class URLValidationError(ValueError):
    """Raised when a URL fails security validation."""
    pass


def validate_url(url: str) -> str:
    """
    Validate and normalise a user-supplied URL.

    Returns the normalised URL string on success.
    Raises URLValidationError on failure.

    Checks:
      - Non-empty string
      - http or https scheme only
      - Non-empty hostname
      - Not a blocked hostname (localhost, metadata endpoints)
      - Hostname does not resolve to a private/reserved IP
      - URL length within reasonable bounds
    """
    if not url or not isinstance(url, str):
        raise URLValidationError("URL must be a non-empty string.")

    url = url.strip()

    if len(url) > 2048:
        raise URLValidationError("URL exceeds maximum allowed length (2048 chars).")

    parsed = urlparse(url)

    if parsed.scheme not in _ALLOWED_SCHEMES:
        raise URLValidationError(
            f"Unsupported URL scheme '{parsed.scheme}'. Only http and https are allowed."
        )

    hostname = parsed.hostname
    if not hostname:
        raise URLValidationError("URL must include a valid hostname.")

    # Strip brackets from IPv6 literals
    hostname_clean = hostname.strip("[]")

    if hostname_clean.lower() in _BLOCKED_HOSTNAMES:
        raise URLValidationError(f"Access to '{hostname_clean}' is not permitted.")

    # Try parsing as IP address directly
    try:
        ip = ipaddress.ip_address(hostname_clean)
        _check_ip(ip)
        return url
    except ValueError:
        pass  # Not a bare IP address — resolve it

    # Resolve hostname to IP and validate
    try:
        addr_infos = socket.getaddrinfo(hostname_clean, None)
    except socket.gaierror as exc:
        raise URLValidationError(f"Unable to resolve hostname '{hostname_clean}': {exc}") from exc

    for addr_info in addr_infos:
        ip_str = addr_info[4][0]
        try:
            ip = ipaddress.ip_address(ip_str)
            _check_ip(ip)
        except URLValidationError:
            raise URLValidationError(
                f"Hostname '{hostname_clean}' resolves to a private/reserved IP address "
                f"({ip_str}). Access is not permitted."
            )

    return url


def _check_ip(ip: ipaddress.IPv4Address | ipaddress.IPv6Address) -> None:
    """Raise URLValidationError if IP is in a private/reserved range."""
    networks = _PRIVATE_V6 if ip.version == 6 else _PRIVATE_NETWORKS
    for net in networks:
        if ip in net:
            raise URLValidationError(
                f"IP address {ip} belongs to a private/reserved network ({net}). "
                "SSRF protection: access denied."
            )


def is_direct_media_url(url: str) -> bool:
    """Return True if the URL path ends with a known direct media extension."""
    parsed = urlparse(url.lower())
    path = parsed.path.rstrip("/")
    direct_extensions = {".mp4", ".mkv", ".webm", ".mov", ".avi", ".m3u8", ".mpd", ".ogg", ".ts"}
    for ext in direct_extensions:
        if path.endswith(ext):
            return True
    return False


def detect_stream_type(url: str, content_type: str | None = None) -> str:
    """
    Detect the stream type from URL and/or content-type header.

    Returns one of: 'direct', 'hls', 'dash', 'embed', 'unknown'
    """
    lower_url = url.lower()
    lower_ct = (content_type or "").lower()

    if ".m3u8" in lower_url or "mpegurl" in lower_ct or "hls" in lower_ct:
        return "hls"
    if ".mpd" in lower_url or "dash+xml" in lower_ct:
        return "dash"
    if any(lower_url.endswith(ext) for ext in (".mp4", ".mkv", ".webm", ".mov", ".avi", ".ogg")):
        return "direct"
    if "video/" in lower_ct:
        return "direct"
    return "unknown"
