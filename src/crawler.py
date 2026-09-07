from __future__ import annotations

import asyncio
import logging
import ssl
from collections.abc import Sequence
from typing import Final

import aiohttp
from bs4 import BeautifulSoup

try:
    from config import Settings
    from database import Database
    from models import CrawlStats
    from net import PerHostRateLimiter, RobotsCache
    from utils import (
        canonical_directory_url,
        canonicalize_seed_url,
        get_file_name,
        get_file_type,
        is_directory_url,
        is_within_directory,
        normalize_url,
        should_index_file,
    )
except ImportError:
    from src.config import Settings
    from src.database import Database
    from src.models import CrawlStats
    from src.net import PerHostRateLimiter, RobotsCache
    from src.utils import (
        canonical_directory_url,
        canonicalize_seed_url,
        get_file_name,
        get_file_type,
        is_directory_url,
        is_within_directory,
        normalize_url,
        should_index_file,
    )

_LOGGER: Final = logging.getLogger("indexer.crawler")


class AsyncDirectoryCrawler:
    def __init__(self, settings: Settings, database: Database) -> None:
        self._settings = settings
        self._database = database
        self._semaphore = asyncio.Semaphore(settings.max_concurrent_requests)
        self._rate_limiter = PerHostRateLimiter(settings.per_host_delay_seconds)
        self._robots_cache = RobotsCache(
            verify_ssl=settings.verify_ssl,
            timeout_seconds=settings.request_timeout_seconds,
        )
        self._stats = CrawlStats()
        self._visited_directories: set[str] = set()

    async def crawl_seeds(self, seed_urls: Sequence[str]) -> CrawlStats:
        queue: asyncio.Queue[tuple[str, int, str]] = asyncio.Queue()

        for raw_seed in seed_urls:
            seed = canonicalize_seed_url(raw_seed)
            if seed is None:
                _LOGGER.warning("Skipping invalid seed URL: %s", raw_seed)
                continue

            directory_key = canonical_directory_url(seed)
            if directory_key in self._visited_directories:
                continue

            self._visited_directories.add(directory_key)
            queue.put_nowait((seed, 0, directory_key))
            self._stats.directories_queued += 1

        if queue.empty():
            return self._stats

        headers = {
            "User-Agent": self._settings.user_agent,
            "Accept": "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8",
        }
        connector = aiohttp.TCPConnector(
            limit=self._settings.max_concurrent_requests,
            ssl=self._settings.verify_ssl,
        )
        timeout = aiohttp.ClientTimeout(
            total=self._settings.request_timeout_seconds
        )

        async with aiohttp.ClientSession(
            connector=connector,
            headers=headers,
            timeout=timeout,
        ) as session:
            workers = [
                asyncio.create_task(
                    self._worker(session, queue, worker_id),
                    name=f"crawler-worker-{worker_id}",
                )
                for worker_id in range(self._settings.max_concurrent_requests)
            ]

            await queue.join()

            for worker in workers:
                worker.cancel()

            await asyncio.gather(*workers, return_exceptions=True)

        return self._stats

    async def _worker(
        self,
        session: aiohttp.ClientSession,
        queue: asyncio.Queue[tuple[str, int, str]],
        worker_id: int,
    ) -> None:
        _ = worker_id

        while True:
            try:
                url, depth, root = await queue.get()
            except asyncio.CancelledError:
                break

            try:
                await self._process_directory(session, url, depth, root, queue)
            except asyncio.CancelledError:
                raise
            except Exception:
                _LOGGER.exception("Unhandled crawler failure for %s", url)
                self._stats.errors += 1
            finally:
                queue.task_done()

    async def _process_directory(
        self,
        session: aiohttp.ClientSession,
        url: str,
        depth: int,
        root: str,
        queue: asyncio.Queue[tuple[str, int, str]],
    ) -> None:
        if depth > self._settings.max_depth:
            return

        if self._stats.directories_crawled >= self._settings.max_directories:
            return

        if self._settings.obey_robots_txt:
            allowed = await self._robots_cache.is_allowed(
                session, url, self._settings.user_agent
            )
            if not allowed:
                _LOGGER.info("Robots.txt disallows crawling %s; skipping.", url)
                return

        self._stats.directories_crawled += 1

        html = await self._fetch_html(session, url)
        if html is None:
            return

        links = await asyncio.to_thread(self._extract_links, html, url)

        for link in links:
            if is_directory_url(link):
                self._maybe_enqueue_directory(link, depth, root, queue)
            elif should_index_file(link):
                await self._maybe_index_file(session, link)

    def _maybe_enqueue_directory(
        self,
        link: str,
        depth: int,
        root: str,
        queue: asyncio.Queue[tuple[str, int, str]],
    ) -> None:
        if depth + 1 > self._settings.max_depth:
            return

        if len(self._visited_directories) >= self._settings.max_directories:
            return

        directory_key = canonical_directory_url(link)
        if directory_key in self._visited_directories:
            return

        if not is_within_directory(root, directory_key):
            return

        self._visited_directories.add(directory_key)
        queue.put_nowait((link, depth + 1, root))
        self._stats.directories_queued += 1

    async def _maybe_index_file(
        self,
        session: aiohttp.ClientSession,
        link: str,
    ) -> None:
        if self._stats.files_indexed >= self._settings.max_files:
            return

        file_name = get_file_name(link)
        if not file_name:
            return

        file_type = get_file_type(file_name)
        if file_type == "Other":
            return

        self._stats.files_discovered += 1

        file_size_bytes: int | None = None
        if self._settings.fetch_file_size:
            file_size_bytes = await self._extract_file_size(session, link)

        try:
            inserted = await self._database.insert_file(
                file_name=file_name,
                file_url=link,
                file_type=file_type,
                file_size_bytes=file_size_bytes,
            )
        except Exception:
            _LOGGER.exception("Failed to insert file: %s", link)
            self._stats.errors += 1
            return

        if inserted:
            self._stats.files_indexed += 1

    async def _extract_file_size(
        self,
        session: aiohttp.ClientSession,
        url: str,
    ) -> int | None:
        await self._rate_limiter.acquire(url)
        async with self._semaphore:
            try:
                timeout = aiohttp.ClientTimeout(
                    total=self._settings.head_timeout_seconds
                )
                async with session.head(
                    url,
                    allow_redirects=True,
                    max_redirects=3,
                    ssl=self._settings.verify_ssl,
                    timeout=timeout,
                ) as resp:
                    if resp.status in {200, 206}:
                        content_length = resp.headers.get("Content-Length")
                        if content_length and content_length.isdigit():
                            return int(content_length)
            except Exception as exc:
                _LOGGER.debug("HEAD request failed for %s: %s", url, exc)

            return None

    async def _fetch_html(
        self,
        session: aiohttp.ClientSession,
        url: str,
    ) -> str | None:
        await self._rate_limiter.acquire(url)
        async with self._semaphore:
            try:
                async with session.get(
                    url,
                    allow_redirects=True,
                    max_redirects=5,
                    ssl=self._settings.verify_ssl,
                ) as response:
                    if response.status != 200:
                        _LOGGER.debug("HTTP %s for %s", response.status, url)
                        return None

                    content_type = response.headers.get("Content-Type", "").lower()
                    if content_type and "html" not in content_type:
                        _LOGGER.debug(
                            "Skipping non-HTML content type %s for %s",
                            content_type,
                            url,
                        )
                        return None

                    chunks: list[bytes] = []
                    total_bytes = 0

                    async for chunk in response.content.iter_chunked(65536):
                        total_bytes += len(chunk)

                        if total_bytes > self._settings.max_html_bytes:
                            _LOGGER.debug("HTML payload too large for %s", url)
                            return None

                        chunks.append(chunk)

                    if self._settings.request_delay_seconds > 0:
                        await asyncio.sleep(self._settings.request_delay_seconds)

                    encoding = response.charset or "utf-8"
                    return b"".join(chunks).decode(encoding, errors="replace")

            except asyncio.TimeoutError:
                _LOGGER.debug("Timeout while fetching %s", url)
                self._stats.errors += 1
            except aiohttp.ClientError as exc:
                _LOGGER.debug("HTTP client error for %s: %s", url, exc)
                self._stats.errors += 1
            except ssl.SSLError as exc:
                _LOGGER.debug("SSL error for %s: %s", url, exc)
                self._stats.errors += 1
            except (UnicodeDecodeError, OSError, ValueError) as exc:
                _LOGGER.debug("Failed to fetch or decode %s: %s", url, exc)
                self._stats.errors += 1

            return None

    def _extract_links(self, html: str, fallback_url: str) -> list[str]:
        try:
            soup = BeautifulSoup(html, "html.parser")
        except Exception:
            _LOGGER.debug("Failed to parse HTML from %s", fallback_url)
            return []

        base_url = fallback_url
        base_tag = soup.find("base", href=True)

        if base_tag is not None:
            candidate = normalize_url(
                fallback_url,
                str(base_tag.get("href", "")),
            )
            if candidate is not None:
                base_url = candidate

        links: list[str] = []

        for anchor in soup.find_all("a", href=True):
            href = str(anchor.get("href", "")).strip()
            normalized = normalize_url(base_url, href)

            if normalized is not None:
                links.append(normalized)

        return links
