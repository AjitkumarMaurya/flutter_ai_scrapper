from __future__ import annotations

import asyncio
import logging
import re
import sqlite3
from pathlib import Path
from typing import Any, Final

import aiosqlite

try:
    from utils import normalize_type
except ImportError:
    from src.utils import normalize_type

_LOGGER: Final = logging.getLogger("indexer.database")

_CREATE_TABLE_SQL: Final[str] = """
CREATE TABLE IF NOT EXISTS indexed_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_name TEXT NOT NULL,
    file_url TEXT NOT NULL UNIQUE,
    file_type TEXT NOT NULL,
    file_size_bytes INTEGER,
    discovered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
"""

_CREATE_INDEX_SQL: Final[str] = """
CREATE INDEX IF NOT EXISTS idx_indexed_files_file_name
ON indexed_files(file_name);
"""

_CREATE_FTS_SQL: Final[str] = """
CREATE VIRTUAL TABLE IF NOT EXISTS indexed_files_fts USING fts5(
    file_name,
    file_url UNINDEXED,
    file_type UNINDEXED,
    tokenize='unicode61 remove_diacritics 2'
);
"""


def _escape_like(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace("%", "\\%")
        .replace("_", "\\_")
    )


def _build_fts_query(query: str) -> str:
    tokens = re.findall(r"[\w.\-]+", query.lower(), re.UNICODE)
    parts: list[str] = []

    for token in tokens:
        cleaned = token.strip()
        if not cleaned:
            continue

        escaped = cleaned.replace('"', '""')
        parts.append(f'"{escaped}"*')

    return " ".join(parts)


class Database:
    def __init__(self, path: Path | str) -> None:
        self._path = Path(path)
        self._connection: aiosqlite.Connection | None = None
        self._lock = asyncio.Lock()
        self._fts_enabled = False

    @property
    def fts_enabled(self) -> bool:
        return self._fts_enabled

    async def connect(self) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._connection = await aiosqlite.connect(self._path)
        self._connection.row_factory = aiosqlite.Row

        await self._connection.execute("PRAGMA journal_mode=WAL;")
        await self._connection.execute("PRAGMA synchronous=NORMAL;")
        await self._connection.execute("PRAGMA foreign_keys=ON;")

        await self._initialize_schema()
        await self._initialize_fts()
        await self._sync_fts_missing()
        await self._connection.commit()

    async def close(self) -> None:
        if self._connection is not None:
            await self._connection.close()
            self._connection = None

    async def insert_file(
        self,
        file_name: str,
        file_url: str,
        file_type: str,
        file_size_bytes: int | None = None,
    ) -> bool:
        connection = self._require_connection()
        normalized_type = normalize_type(file_type) or file_type

        async with self._lock:
            cursor = await connection.execute(
                """
                INSERT OR IGNORE INTO indexed_files (
                    file_name,
                    file_url,
                    file_type,
                    file_size_bytes
                )
                VALUES (?, ?, ?, ?);
                """,
                (file_name, file_url, normalized_type, file_size_bytes),
            )

            inserted = cursor.rowcount > 0

            if inserted:
                file_id = cursor.lastrowid
                if self._fts_enabled and file_id is not None:
                    try:
                        await connection.execute(
                            """
                            INSERT INTO indexed_files_fts (
                                rowid,
                                file_name,
                                file_url,
                                file_type
                            )
                            VALUES (?, ?, ?, ?);
                            """,
                            (int(file_id), file_name, file_url, normalized_type),
                        )
                    except sqlite3.Error:
                        _LOGGER.exception(
                            "Failed to insert FTS row for %s; rolling back.",
                            file_url,
                        )
                        await connection.rollback()
                        return False

            await connection.commit()
            return inserted

    async def search(
        self,
        query: str,
        type_filter: str | None = None,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        connection = self._require_connection()
        normalized_type = normalize_type(type_filter)

        if type_filter is not None and normalized_type is None:
            raise ValueError("Invalid type filter.")

        if self._fts_enabled:
            fts_query = _build_fts_query(query)
            if fts_query:
                try:
                    cursor = await connection.execute(
                        """
                        SELECT
                            i.file_name,
                            i.file_url,
                            i.file_type,
                            i.file_size_bytes
                        FROM indexed_files_fts AS f
                        JOIN indexed_files AS i ON i.id = f.rowid
                        WHERE indexed_files_fts MATCH ?
                          AND (? IS NULL OR i.file_type = ?)
                        ORDER BY rank
                        LIMIT ?;
                        """,
                        (fts_query, normalized_type, normalized_type, limit),
                    )
                    rows = await cursor.fetchall()
                    if rows:
                        return [dict(row) for row in rows]
                except sqlite3.Error:
                    _LOGGER.exception(
                        "FTS search failed for query %r; falling back to LIKE.",
                        query,
                    )

        like_pattern = f"%{_escape_like(query.strip())}%"

        if normalized_type is not None:
            cursor = await connection.execute(
                """
                SELECT file_name, file_url, file_type, file_size_bytes
                FROM indexed_files
                WHERE file_name LIKE ? ESCAPE '\\'
                  AND file_type = ?
                ORDER BY file_name
                LIMIT ?;
                """,
                (like_pattern, normalized_type, limit),
            )
        else:
            cursor = await connection.execute(
                """
                SELECT file_name, file_url, file_type, file_size_bytes
                FROM indexed_files
                WHERE file_name LIKE ? ESCAPE '\\'
                ORDER BY file_name
                LIMIT ?;
                """,
                (like_pattern, limit),
            )

        rows = await cursor.fetchall()
        return [dict(row) for row in rows]

    async def get_stats(self) -> dict[str, Any]:
        connection = self._require_connection()

        total_cursor = await connection.execute(
            "SELECT COUNT(*) AS total FROM indexed_files;"
        )
        total_row = await total_cursor.fetchone()
        total_files = int(total_row["total"]) if total_row else 0

        type_cursor = await connection.execute(
            """
            SELECT file_type, COUNT(*) AS total
            FROM indexed_files
            GROUP BY file_type
            ORDER BY total DESC;
            """
        )
        type_rows = await type_cursor.fetchall()

        return {
            "total_files": total_files,
            "by_type": {
                row["file_type"]: int(row["total"]) for row in type_rows
            },
            "fts_enabled": self._fts_enabled,
        }

    async def execute_sql(
        self,
        query: str,
        max_rows: int = 100,
    ) -> dict[str, Any]:
        connection = self._require_connection()
        cleaned = query.strip().rstrip(";")
        if not cleaned:
            raise ValueError("SQL query cannot be empty.")

        first_word = cleaned.split()[0].upper()
        if first_word not in {"SELECT", "WITH", "EXPLAIN", "PRAGMA"}:
            raise ValueError("Only read-only queries (SELECT, WITH, EXPLAIN) are permitted.")

        forbidden = {"DROP", "DELETE", "UPDATE", "INSERT", "ALTER", "ATTACH", "DETACH", "REINDEX", "VACUUM"}
        words = set(re.findall(r"\b[A-Za-z]+\b", cleaned.upper()))
        disallowed = words.intersection(forbidden)
        if disallowed:
            raise ValueError(f"Disallowed keyword(s) in read-only query: {', '.join(sorted(disallowed))}")

        cursor = await connection.execute(cleaned)
        columns = [d[0] for d in cursor.description] if cursor.description else []
        rows = await cursor.fetchmany(max_rows)
        result_rows = [[row[col] for col in columns] for row in rows]
        return {
            "columns": columns,
            "rows": result_rows,
            "count": len(result_rows),
        }

    async def _initialize_schema(self) -> None:
        connection = self._require_connection()
        await connection.execute(_CREATE_TABLE_SQL)
        await connection.execute(_CREATE_INDEX_SQL)

        # Automated schema migration for existing databases
        cursor = await connection.execute("PRAGMA table_info(indexed_files);")
        rows = await cursor.fetchall()
        columns = [row["name"] for row in rows]
        if "file_size_bytes" not in columns:
            await connection.execute(
                "ALTER TABLE indexed_files ADD COLUMN file_size_bytes INTEGER;"
            )

    async def _initialize_fts(self) -> None:
        connection = self._require_connection()

        try:
            await connection.execute(_CREATE_FTS_SQL)
            self._fts_enabled = True
        except sqlite3.OperationalError as exc:
            self._fts_enabled = False
            _LOGGER.warning(
                "FTS5 is unavailable (%s); using LIKE fallback.",
                exc,
            )

    async def _sync_fts_missing(self) -> None:
        if not self._fts_enabled:
            return

        connection = self._require_connection()
        await connection.execute(
            """
            INSERT INTO indexed_files_fts (
                rowid,
                file_name,
                file_url,
                file_type
            )
            SELECT
                source.id,
                source.file_name,
                source.file_url,
                source.file_type
            FROM indexed_files AS source
            WHERE NOT EXISTS (
                SELECT 1
                FROM indexed_files_fts AS target
                WHERE target.rowid = source.id
            );
            """
        )

    def _require_connection(self) -> aiosqlite.Connection:
        if self._connection is None:
            raise RuntimeError("Database connection is not initialized.")

        return self._connection
