from __future__ import annotations

from pathlib import Path

import pytest

from database import Database


@pytest.fixture
async def db(tmp_path: Path):
    db_path = tmp_path / "test_indexer.db"
    database = Database(db_path)
    await database.connect()
    try:
        yield database
    finally:
        await database.close()


@pytest.mark.asyncio
async def test_insert_and_duplicate_suppression(db: Database) -> None:
    # First insert succeeds
    inserted = await db.insert_file(
        file_name="ubuntu-24.04-desktop-amd64.iso",
        file_url="https://mirror.example.org/ubuntu.iso",
        file_type="Archive",
    )
    assert inserted is True

    # Duplicate URL insert is ignored
    duplicate = await db.insert_file(
        file_name="ubuntu-duplicate.iso",
        file_url="https://mirror.example.org/ubuntu.iso",
        file_type="Archive",
    )
    assert duplicate is False

    stats = await db.get_stats()
    assert stats["total_files"] == 1


@pytest.mark.asyncio
async def test_search_and_type_filtering(db: Database) -> None:
    await db.insert_file("debian-netinst.iso", "https://debian.org/netinst.iso", "Archive")
    await db.insert_file("debian-guide.pdf", "https://debian.org/guide.pdf", "Document")
    await db.insert_file("debian-intro.mp4", "https://debian.org/intro.mp4", "Video")

    # Search with keyword matching multiple
    results = await db.search("debian")
    assert len(results) == 3

    # Search with type filter
    archive_results = await db.search("debian", type_filter="archive")
    assert len(archive_results) == 1
    assert archive_results[0]["file_name"] == "debian-netinst.iso"

    # Search with limit
    limited_results = await db.search("debian", limit=2)
    assert len(limited_results) == 2

    # Invalid type filter raises ValueError
    with pytest.raises(ValueError, match="Invalid type filter"):
        await db.search("debian", type_filter="invalid_category")


@pytest.mark.asyncio
async def test_like_fallback(tmp_path: Path) -> None:
    # Force disable FTS5 to test fallback
    db_path = tmp_path / "test_no_fts.db"
    database = Database(db_path)
    await database.connect()
    database._fts_enabled = False

    await database.insert_file("movie_part_1.mkv", "https://example.com/movie_1.mkv", "Video")
    await database.insert_file("movie_part_2.mkv", "https://example.com/movie_2.mkv", "Video")
    await database.insert_file("soundtrack.mp3", "https://example.com/sound.mp3", "Audio")

    results = await database.search("movie", type_filter="video")
    assert len(results) == 2
    assert results[0]["file_name"] == "movie_part_1.mkv"

    await database.close()


@pytest.mark.asyncio
async def test_stats_aggregation(db: Database) -> None:
    await db.insert_file("clip1.mp4", "https://ex.com/1.mp4", "Video")
    await db.insert_file("clip2.mp4", "https://ex.com/2.mp4", "Video")
    await db.insert_file("song.mp3", "https://ex.com/song.mp3", "Audio")

    stats = await db.get_stats()
    assert stats["total_files"] == 3
    assert stats["by_type"]["Video"] == 2
    assert stats["by_type"]["Audio"] == 1


@pytest.mark.asyncio
async def test_file_size_storage_and_search(db: Database) -> None:
    await db.insert_file(
        file_name="large_iso.iso",
        file_url="https://ex.com/iso.iso",
        file_type="Archive",
        file_size_bytes=4294967296,
    )
    results = await db.search("large_iso")
    assert len(results) == 1
    assert results[0]["file_size_bytes"] == 4294967296


@pytest.mark.asyncio
async def test_database_schema_migration(tmp_path: Path) -> None:
    import aiosqlite
    db_path = tmp_path / "legacy_indexer.db"

    # Create legacy table without file_size_bytes
    async with aiosqlite.connect(db_path) as conn:
        await conn.execute("""
            CREATE TABLE indexed_files (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                file_name TEXT NOT NULL,
                file_url TEXT NOT NULL UNIQUE,
                file_type TEXT NOT NULL,
                discovered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        await conn.commit()

    # Now connect with Database class, which should trigger automatic ALTER TABLE
    db = Database(db_path)
    await db.connect()

    inserted = await db.insert_file(
        "migrated.mp4",
        "https://ex.com/migrated.mp4",
        "Video",
        file_size_bytes=1048576,
    )
    assert inserted is True

    res = await db.search("migrated")
    assert len(res) == 1
    assert res[0]["file_size_bytes"] == 1048576

    await db.close()


@pytest.mark.asyncio
async def test_execute_sql_allowed_and_disallowed(db: Database) -> None:
    await db.insert_file("video1.mp4", "https://ex.com/1.mp4", "Video", 1000)
    await db.insert_file("video2.mp4", "https://ex.com/2.mp4", "Video", 2000)

    # Valid SELECT query
    res = await db.execute_sql("SELECT file_name, file_size_bytes FROM indexed_files ORDER BY file_size_bytes DESC;")
    assert res["count"] == 2
    assert res["columns"] == ["file_name", "file_size_bytes"]
    assert res["rows"][0][0] == "video2.mp4"
    assert res["rows"][0][1] == 2000

    # Disallowed DROP statement
    with pytest.raises(ValueError, match="Only read-only queries"):
        await db.execute_sql("DROP TABLE indexed_files;")

    # Disallowed DELETE statement
    with pytest.raises(ValueError, match="Only read-only queries"):
        await db.execute_sql("DELETE FROM indexed_files;")

    # Disallowed INSERT keyword embedded
    with pytest.raises(ValueError, match="Disallowed keyword"):
        await db.execute_sql("SELECT * FROM indexed_files; INSERT INTO indexed_files VALUES (1, 'a', 'b', 'c', 1, 'now');")
