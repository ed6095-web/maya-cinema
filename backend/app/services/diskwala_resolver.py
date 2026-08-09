# MAYA — Diskwala Stream Resolver
# Uses Playwright headless browser to intercept signed stream URL from Diskwala API.
# The Diskwala API requires a WebAssembly-generated 'Appicrypt' header that can only
# be produced by running their JavaScript — so we run real headless Chrome, intercept
# the /file/sign API response (which contains the signed S3 URL), and return it.

import asyncio
import re
import logging
from typing import Optional

log = logging.getLogger(__name__)

# Cache resolved URLs so we don't re-resolve the same link repeatedly
_cache: dict[str, str] = {}

async def resolve_diskwala_stream(diskwala_url: str) -> Optional[str]:
    """
    Given a Diskwala share URL like https://www.diskwala.com/app/<id>,
    launches a headless Chromium browser, intercepts the POST /file/sign
    API response which contains the signed S3 download/stream URL,
    and returns the direct MP4/stream URL ready for native playback.

    Returns None if resolution fails.
    """
    if diskwala_url in _cache:
        log.info(f"Cache hit for {diskwala_url}")
        return _cache[diskwala_url]

    try:
        from playwright.async_api import async_playwright
    except ImportError:
        log.error("playwright not installed. Run: pip install playwright && playwright install chromium")
        return None

    stream_url: Optional[str] = None

    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(
                headless=True,
                args=[
                    "--no-sandbox",
                    "--disable-setuid-sandbox",
                    "--disable-dev-shm-usage",
                    "--disable-gpu",
                    "--disable-web-security",
                    "--disable-features=VizDisplayCompositor",
                ],
            )

            context = await browser.new_context(
                user_agent="Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36",
                viewport={"width": 412, "height": 915},
            )

            page = await context.new_page()

            # Intercept API responses to capture the signed URL from /file/sign
            signed_url_event = asyncio.Event()

            async def handle_response(response):
                nonlocal stream_url
                try:
                    if "/file/sign" in response.url and response.status == 200:
                        body = await response.json()
                        log.info(f"Intercepted /file/sign response: {str(body)[:300]}")
                        # The signed URL is typically in body.url or body.signed_url or body.download_url
                        url = (
                            body.get("url")
                            or body.get("signed_url")
                            or body.get("download_url")
                            or body.get("stream_url")
                            or body.get("file_url")
                        )
                        if not url:
                            # Try nested data
                            data = body.get("data") or {}
                            url = (
                                data.get("url")
                                or data.get("signed_url")
                                or data.get("download_url")
                                or data.get("stream_url")
                            )
                        if url:
                            stream_url = url
                            signed_url_event.set()
                            log.info(f"Got signed stream URL: {url[:100]}")
                except Exception as e:
                    log.debug(f"Response parse error: {e}")

            page.on("response", handle_response)

            log.info(f"Opening Diskwala page: {diskwala_url}")
            await page.goto(diskwala_url, wait_until="domcontentloaded", timeout=30000)

            # Wait up to 15 seconds for the signed URL to be intercepted
            try:
                await asyncio.wait_for(signed_url_event.wait(), timeout=15.0)
            except asyncio.TimeoutError:
                log.warning("Timeout waiting for /file/sign response — URL not intercepted")

            await browser.close()

    except Exception as e:
        log.error(f"Playwright error resolving {diskwala_url}: {e}")
        return None

    if stream_url:
        _cache[diskwala_url] = stream_url

    return stream_url


def extract_diskwala_id(url: str) -> Optional[str]:
    """Extract the 24-char hex ID from a Diskwala share URL."""
    match = re.search(r"[a-f0-9]{24}", url)
    return match.group(0) if match else None


def is_diskwala_url(url: str) -> bool:
    """Check if a URL is a Diskwala share link."""
    return "diskwala.com" in url.lower()
