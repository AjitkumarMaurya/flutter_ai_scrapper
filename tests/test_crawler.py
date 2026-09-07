from __future__ import annotations

import asyncio
import ssl
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import aiohttp
import pytest

from config import Settings
from crawler import AsyncDirectoryCrawler
from database import Database


@pytest.fixture
async def crawler_and_db(tmp_path: Path):
    db_path = tmp_path / "crawler_test.db"
    db = Database(db_path)
    await db.connect()

    settings = Settings(
        database_path=db_path,
        max_concurrent_requests=2,
        request_delay_seconds=0.0,
        max_depth=2,
        max_directories=10,
        max_files=50,
    )
    crawler = AsyncDirectoryCrawler(settings, db)

    try:
        yield crawler, db, settings
    finally:
        await db.close()


def _mock_response(status=200, content_type="text/html", text=""):
    resp = AsyncMock()
    resp.status = status
    resp.headers = {"Content-Type": content_type}
    resp.charset = "utf-8"
    resp.text = AsyncMock(return_value=text)

    async def iter_chunked(size):
        yield text.encode("utf-8")

    content_mock = MagicMock()
    content_mock.iter_chunked = iter_chunked
    resp.content = content_mock

    # Context manager mock
    cm = AsyncMock()
    cm.__aenter__.return_value = resp
    cm.__aexit__.return_value = None
    return cm


@pytest.mark.asyncio
async def test_crawler_extracts_links_and_indexes(crawler_and_db) -> None:
    crawler, db, settings = crawler_and_db

    html_content = """
    <html>
        <head><title>Index of /pub/</title></head>
        <body>
            <a href="../">Parent Directory</a>
            <a href="iso/">iso/</a>
            <a href="docs/readme.pdf">readme.pdf</a>
            <a href="script.js">script.js</a>
            <a href="image.png">image.png</a>
        </body>
    </html>
    """

    iso_html = """
    <html>
        <body>
            <a href="ubuntu.iso">ubuntu.iso</a>
            <a href="fedora.iso">fedora.iso</a>
        </body>
    </html>
    """

    def mock_get(url, **kwargs):
        if url == "https://mirror.example.org/pub/":
            return _mock_response(200, "text/html", html_content)
        elif url == "https://mirror.example.org/pub/iso/":
            return _mock_response(200, "text/html", iso_html)
        return _mock_response(404, "text/html", "Not Found")

    with patch("aiohttp.ClientSession.get", side_effect=mock_get):
        stats = await crawler.crawl_seeds(["https://mirror.example.org/pub/"])

    assert stats.directories_crawled >= 2
    # readme.pdf + ubuntu.iso + fedora.iso = 3 indexed files (script.js and image.png excluded)
    assert stats.files_indexed == 3

    search_res = await db.search("ubuntu")
    assert len(search_res) == 1
    assert search_res[0]["file_name"] == "ubuntu.iso"


@pytest.mark.asyncio
async def test_crawler_respects_base_tag(crawler_and_db) -> None:
    crawler, db, settings = crawler_and_db

    html_with_base = """
    <html>
        <head><base href="https://mirror.example.org/pub/custom/"></head>
        <body>
            <a href="data.zip">data.zip</a>
        </body>
    </html>
    """

    with patch("aiohttp.ClientSession.get", return_value=_mock_response(200, "text/html", html_with_base)):
        stats = await crawler.crawl_seeds(["https://mirror.example.org/pub/"])

    assert stats.files_indexed == 1
    search_res = await db.search("data.zip")
    assert len(search_res) == 1
    assert search_res[0]["file_url"] == "https://mirror.example.org/pub/custom/data.zip"


@pytest.mark.asyncio
async def test_crawler_handles_network_failures(crawler_and_db) -> None:
    crawler, db, settings = crawler_and_db

    # Simulate Timeout
    timeout_cm = AsyncMock()
    timeout_cm.__aenter__.side_effect = asyncio.TimeoutError()

    with patch("aiohttp.ClientSession.get", return_value=timeout_cm):
        stats = await crawler.crawl_seeds(["https://timeout.example.org/pub/"])
        assert stats.errors > 0

    # Simulate SSL Error
    ssl_cm = AsyncMock()
    ssl_cm.__aenter__.side_effect = ssl.SSLError("SSL handshake failed")

    with patch("aiohttp.ClientSession.get", return_value=ssl_cm):
        stats = await crawler.crawl_seeds(["https://badssl.example.org/pub/"])
        assert stats.errors > 0

    # Simulate ClientError
    client_err_cm = AsyncMock()
    client_err_cm.__aenter__.side_effect = aiohttp.ClientConnectionError("Connection refused")

    with patch("aiohttp.ClientSession.get", return_value=client_err_cm):
        stats = await crawler.crawl_seeds(["https://deadhost.example.org/pub/"])
        assert stats.errors > 0


@pytest.mark.asyncio
async def test_crawler_handles_non_200_and_non_html(crawler_and_db) -> None:
    crawler, db, settings = crawler_and_db

    # Non-200 response
    with patch("aiohttp.ClientSession.get", return_value=_mock_response(status=500, text="Internal Server Error")):
        stats = await crawler.crawl_seeds(["https://mirror.example.org/pub/"])
        assert stats.files_indexed == 0

    # Non-HTML response (e.g. application/json or octet-stream)
    with patch("aiohttp.ClientSession.get", return_value=_mock_response(status=200, content_type="application/json", text='{"key": "val"}')):
        stats = await crawler.crawl_seeds(["https://mirror.example.org/json/"])
        assert stats.files_indexed == 0


@pytest.mark.asyncio
async def test_crawler_oversized_payload_skipped(tmp_path: Path) -> None:
    db_path = tmp_path / "oversize_test.db"
    db = Database(db_path)
    await db.connect()

    settings = Settings(
        database_path=db_path,
        max_html_bytes=100,  # very small threshold
        request_delay_seconds=0.0,
    )
    crawler = AsyncDirectoryCrawler(settings, db)

    large_html = "<html><body>" + ("<a href='file.mp4'>video</a>" * 50) + "</body></html>"
    with patch("aiohttp.ClientSession.get", return_value=_mock_response(status=200, text=large_html)):
        stats = await crawler.crawl_seeds(["https://mirror.example.org/pub/"])
        assert stats.files_indexed == 0

    await db.close()


@pytest.mark.asyncio
async def test_crawler_empty_seed_list(crawler_and_db) -> None:
    crawler, db, settings = crawler_and_db
    stats = await crawler.crawl_seeds([])
    assert stats.directories_queued == 0
    assert stats.directories_crawled == 0


@pytest.mark.asyncio
async def test_crawler_robots_txt_disallowed(crawler_and_db) -> None:
    crawler, db, settings = crawler_and_db

    robots_txt = "User-agent: *\nDisallow: /pub/secret/\n"
    root_html = '<html><body><a href="secret/">secret/</a><a href="public/">public/</a></body></html>'
    public_html = '<html><body><a href="file.pdf">file.pdf</a></body></html>'

    def mock_get(url, **kwargs):
        if url == "https://mirror.example.org/robots.txt":
            return _mock_response(200, "text/plain", robots_txt)
        elif url == "https://mirror.example.org/pub/":
            return _mock_response(200, "text/html", root_html)
        elif url == "https://mirror.example.org/pub/public/":
            return _mock_response(200, "text/html", public_html)
        elif url == "https://mirror.example.org/pub/secret/":
            raise AssertionError("Secret URL should not be requested when disallowed by robots.txt!")
        return _mock_response(404, "text/html", "Not Found")

    with patch("aiohttp.ClientSession.get", side_effect=mock_get):
        stats = await crawler.crawl_seeds(["https://mirror.example.org/pub/"])

    assert stats.files_indexed == 1
    res = await db.search("file.pdf")
    assert len(res) == 1


@pytest.mark.asyncio
async def test_crawler_file_size_extraction(crawler_and_db) -> None:
    crawler, db, settings = crawler_and_db

    html = '<html><body><a href="ubuntu.iso">ubuntu.iso</a></body></html>'

    head_resp = AsyncMock()
    head_resp.status = 200
    head_resp.headers = {"Content-Length": "2147483648"}
    head_cm = AsyncMock()
    head_cm.__aenter__.return_value = head_resp
    head_cm.__aexit__.return_value = None

    with patch("aiohttp.ClientSession.get", return_value=_mock_response(200, "text/html", html)), \
         patch("aiohttp.ClientSession.head", return_value=head_cm):
        stats = await crawler.crawl_seeds(["https://mirror.example.org/pub/"])

    assert stats.files_indexed == 1
    res = await db.search("ubuntu.iso")
    assert len(res) == 1
    assert res[0]["file_size_bytes"] == 2147483648
