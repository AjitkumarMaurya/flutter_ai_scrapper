from __future__ import annotations

import asyncio
import logging
import time
from typing import Final
from urllib.parse import urlsplit, urlunsplit
from urllib.robotparser import RobotFileParser

import aiohttp

_LOGGER: Final = logging.getLogger("indexer.net")


class PerHostRateLimiter:
    """Limits request frequency on a per-host basis."""

    def __init__(self, delay_seconds: float) -> None:
        self._delay_seconds = max(0.0, delay_seconds)
        self._locks: dict[str, asyncio.Lock] = {}
        self._last_request: dict[str, float] = {}
        self._global_lock = asyncio.Lock()

    async def acquire(self, url: str) -> None:
        if self._delay_seconds <= 0.0:
            return

        netloc = urlsplit(url).netloc.lower()
        if not netloc:
            return

        async with self._global_lock:
            if netloc not in self._locks:
                self._locks[netloc] = asyncio.Lock()
            host_lock = self._locks[netloc]

        async with host_lock:
            now = time.monotonic()
            last_time = self._last_request.get(netloc, 0.0)
            elapsed = now - last_time

            if elapsed < self._delay_seconds:
                sleep_duration = self._delay_seconds - elapsed
                await asyncio.sleep(sleep_duration)

            self._last_request[netloc] = time.monotonic()


class RobotsCache:
    """Fetches, parses, and caches robots.txt rules per host."""

    def __init__(self, verify_ssl: bool = True, timeout_seconds: float = 10.0) -> None:
        self._verify_ssl = verify_ssl
        self._timeout_seconds = timeout_seconds
        self._parsers: dict[str, RobotFileParser] = {}
        self._lock = asyncio.Lock()

    async def is_allowed(
        self,
        session: aiohttp.ClientSession,
        url: str,
        user_agent: str,
    ) -> bool:
        parsed = urlsplit(url)
        if not parsed.netloc:
            return True

        netloc = parsed.netloc.lower()
        scheme = parsed.scheme.lower() or "https"

        async with self._lock:
            if netloc in self._parsers:
                parser = self._parsers[netloc]
                return parser.can_fetch(user_agent, url)

        robots_url = urlunsplit((scheme, netloc, "/robots.txt", "", ""))
        parser = RobotFileParser()

        try:
            timeout = aiohttp.ClientTimeout(total=self._timeout_seconds)
            async with session.get(
                robots_url,
                allow_redirects=True,
                max_redirects=3,
                ssl=self._verify_ssl,
                timeout=timeout,
            ) as response:
                if response.status == 200:
                    text = await response.text(errors="replace")
                    parser.parse(text.splitlines())
                else:
                    _LOGGER.debug(
                        "No robots.txt for %s (HTTP %s); allowing all.",
                        netloc,
                        response.status,
                    )
                    parser.allow_all = True
        except Exception as exc:
            _LOGGER.debug(
                "Unable to fetch robots.txt for %s (%s); allowing all.",
                netloc,
                exc,
            )
            parser.allow_all = True

        async with self._lock:
            self._parsers[netloc] = parser

        return parser.can_fetch(user_agent, url)
