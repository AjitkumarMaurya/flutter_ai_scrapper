from __future__ import annotations

from pathlib import Path

import httpx
import pytest

from app import create_app
from config import Settings
from database import Database


@pytest.fixture
async def client(tmp_path: Path):
    db_path = tmp_path / "api_test.db"
    db = Database(db_path)
    await db.connect()

    await db.insert_file(
        "ubuntu-24.04-desktop-amd64.iso",
        "https://mirror.example.org/releases/ubuntu-24.04-desktop-amd64.iso",
        "Archive",
        file_size_bytes=4294967296,
    )
    await db.insert_file(
        "ubuntu-server-guide.pdf",
        "https://mirror.example.org/releases/ubuntu-server-guide.pdf",
        "Document",
        file_size_bytes=1048576,
    )

    settings = Settings(database_path=db_path)
    app = create_app(database=db, settings=settings)

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as ac:
        yield ac

    await db.close()


@pytest.mark.asyncio
async def test_health_endpoint(client: httpx.AsyncClient) -> None:
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.asyncio
async def test_stats_endpoint(client: httpx.AsyncClient) -> None:
    response = await client.get("/stats")
    assert response.status_code == 200
    data = response.json()
    assert data["total_files"] == 2
    assert data["by_type"]["Archive"] == 1
    assert data["by_type"]["Document"] == 1


@pytest.mark.asyncio
async def test_search_successful(client: httpx.AsyncClient) -> None:
    response = await client.get("/search?q=ubuntu")
    assert response.status_code == 200
    data = response.json()
    assert data["count"] == 2
    assert data["query"] == "ubuntu"
    assert len(data["results"]) == 2


@pytest.mark.asyncio
async def test_search_with_type_filter(client: httpx.AsyncClient) -> None:
    response = await client.get("/search?q=ubuntu&type=archive")
    assert response.status_code == 200
    data = response.json()
    assert data["count"] == 1
    assert data["type"] == "Archive"
    assert data["results"][0]["file_name"] == "ubuntu-24.04-desktop-amd64.iso"
    assert data["results"][0]["file_size_bytes"] == 4294967296


@pytest.mark.asyncio
async def test_search_empty_results(client: httpx.AsyncClient) -> None:
    response = await client.get("/search?q=nonexistent_file_name_12345")
    assert response.status_code == 200
    data = response.json()
    assert data["count"] == 0
    assert data["results"] == []


@pytest.mark.asyncio
async def test_search_missing_query(client: httpx.AsyncClient) -> None:
    response = await client.get("/search")
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_search_invalid_type_filter(client: httpx.AsyncClient) -> None:
    response = await client.get("/search?q=ubuntu&type=invalid_type")
    assert response.status_code == 400
    assert "Invalid type filter" in response.json()["detail"]


@pytest.mark.asyncio
async def test_search_limit_validation(client: httpx.AsyncClient) -> None:
    # limit must be >= 1 and <= 200
    response = await client.get("/search?q=ubuntu&limit=0")
    assert response.status_code == 422

    response = await client.get("/search?q=ubuntu&limit=250")
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_playground_dashboard_html(client: httpx.AsyncClient) -> None:
    res_root = await client.get("/")
    assert res_root.status_code == 200
    assert "text/html" in res_root.headers.get("content-type", "")
    assert "FilePursuit Indexer" in res_root.text

    res_playground = await client.get("/playground")
    assert res_playground.status_code == 200
    assert "text/html" in res_playground.headers.get("content-type", "")


@pytest.mark.asyncio
async def test_api_sql_endpoint(client: httpx.AsyncClient) -> None:
    # Valid SELECT query
    res = await client.post("/api/sql", json={"query": "SELECT file_name, file_type FROM indexed_files;"})
    assert res.status_code == 200
    data = res.json()
    assert data["count"] >= 1
    assert "columns" in data
    assert "rows" in data

    # Disallowed mutation query
    res_bad = await client.post("/api/sql", json={"query": "DROP TABLE indexed_files;"})
    assert res_bad.status_code == 400


@pytest.mark.asyncio
async def test_api_crawl_endpoint(client: httpx.AsyncClient) -> None:
    res = await client.post("/api/crawl", json={"seed_url": "https://example.com/test/", "max_depth": 1})
    assert res.status_code == 200
    assert res.json()["status"] == "crawling_started"
