from __future__ import annotations

import asyncio
import time
from unittest.mock import AsyncMock, patch

import aiohttp
import pytest

from net import PerHostRateLimiter, RobotsCache


@pytest.mark.asyncio
async def test_per_host_rate_limiter_spaces_same_host() -> None:
    limiter = PerHostRateLimiter(delay_seconds=0.1)

    t0 = time.monotonic()
    await limiter.acquire("https://example.com/page1")
    await limiter.acquire("https://example.com/page2")
    t1 = time.monotonic()

    # Two requests to same host must take >= 0.1s
    assert (t1 - t0) >= 0.08


@pytest.mark.asyncio
async def test_per_host_rate_limiter_parallel_different_hosts() -> None:
    limiter = PerHostRateLimiter(delay_seconds=0.2)

    t0 = time.monotonic()
    # Concurrent acquires for different hosts
    await asyncio.gather(
        limiter.acquire("https://host-a.com/page1"),
        limiter.acquire("https://host-b.com/page1"),
        limiter.acquire("https://host-c.com/page1"),
    )
    t1 = time.monotonic()

    # Since all hosts are distinct, total elapsed should be much less than 3 * 0.2s
    assert (t1 - t0) < 0.15


@pytest.mark.asyncio
async def test_robots_cache_disallow_and_allow() -> None:
    cache = RobotsCache()

    robots_txt_content = """
    User-agent: *
    Disallow: /secret/
    Disallow: /admin/
    """

    resp = AsyncMock()
    resp.status = 200
    resp.text = AsyncMock(return_value=robots_txt_content)

    cm = AsyncMock()
    cm.__aenter__.return_value = resp
    cm.__aexit__.return_value = None

    session = AsyncMock(spec=aiohttp.ClientSession)
    session.get.return_value = cm

    # /secret/ is disallowed
    allowed_secret = await cache.is_allowed(
        session, "https://example.com/secret/file.mp4", "OpenDirectoryFileIndexer/1.0"
    )
    assert allowed_secret is False

    # /public/ is allowed
    allowed_public = await cache.is_allowed(
        session, "https://example.com/public/file.mp4", "OpenDirectoryFileIndexer/1.0"
    )
    assert allowed_public is True

    # Check that session.get was called only once (cached)
    assert session.get.call_count == 1


@pytest.mark.asyncio
async def test_robots_cache_404_allows_all() -> None:
    cache = RobotsCache()

    resp = AsyncMock()
    resp.status = 404

    cm = AsyncMock()
    cm.__aenter__.return_value = resp
    cm.__aexit__.return_value = None

    session = AsyncMock(spec=aiohttp.ClientSession)
    session.get.return_value = cm

    allowed = await cache.is_allowed(
        session, "https://example.com/anything/doc.pdf", "OpenDirectoryFileIndexer/1.0"
    )
    assert allowed is True


@pytest.mark.asyncio
async def test_robots_cache_network_error_allows_all() -> None:
    cache = RobotsCache()

    session = AsyncMock(spec=aiohttp.ClientSession)
    session.get.side_effect = aiohttp.ClientError("DNS lookup failed")

    allowed = await cache.is_allowed(
        session, "https://example.com/folder/file.iso", "OpenDirectoryFileIndexer/1.0"
    )
    assert allowed is True
