# PROJECT_DEVELOPMENT_PLAN.md

**Project Name:** Asynchronous Open-Directory File Indexer and Search Engine  
**Date:** 2026-09-07  
**Primary Stack:** Python 3.11+, aiohttp, BeautifulSoup4, aiosqlite, FastAPI, Uvicorn  
**Architecture Style:** Modular asynchronous backend engine  
**Deployment Target:** Lightweight local or VPS backend service  
**UI Dependency:** None; backend-only JSON API

---

## 1. Executive Summary

This project implements a modular, high-performance, asynchronous web file indexer and search engine inspired by FilePursuit. The system crawls open-directory web listings, extracts direct file links, categorizes them by extension, stores them in a lightweight SQLite index, and exposes a FastAPI JSON search endpoint.

The system is intentionally backend-only. It avoids frontend frameworks, external UI dependencies, and heavy infrastructure. The design favors:

- Asynchronous I/O for crawling and API serving.
- SQLite for simple, portable persistence.
- FTS5 when available, with safe fallback to `LIKE`.
- Explicit typing and robust exception handling.
- Modular separation between crawler, database, utilities, and API.
- Politeness controls, including a global request semaphore and request delay.

---

## 2. Goals

### 2.1 Primary Goals

1. Crawl open-directory listing pages asynchronously.
2. Detect and distinguish directory links from direct file links.
3. Exclude common web assets such as HTML, CSS, JavaScript, and SVG.
4. Categorize files into broad groups:
   - Video
   - Audio
   - Document
   - Archive
   - Executable
5. Store indexed files in SQLite with a unique URL constraint.
6. Create an index on `file_name` for faster lookup.
7. Provide a FastAPI `/search` endpoint.
8. Support optional filtering by file category.
9. Return clean JSON results containing:
   - `file_name`
   - `file_url`
   - `file_type`
10. Handle dead domains, timeouts, malformed HTML, invalid URLs, and SSL failures gracefully.

### 2.2 Non-Goals

This version intentionally does not include:

- Distributed queue workers such as Celery or RabbitMQ.
- JavaScript rendering or headless browser crawling.
- Authentication or multi-tenant authorization.
- Administrative frontend dashboard.
- Full distributed cluster coordination.
- Automated proxy rotation.
- Download proxying or file mirroring.
- Deduplication by content hash.
- robots.txt enforcement engine, although politeness controls are included.

These can be added as future extensions.

---

## 3. High-Level Architecture

```text
                 +----------------------+
                 |      Seed URLs       |
                 +----------+-----------+
                            |
                            v
                 +----------------------+
                 |   crawler.py         |
                 | AsyncDirectoryCrawler|
                 +----------+-----------+
                            |
             HTML fetch via aiohttp + semaphore
                            |
                            v
                 +----------------------+
                 | BeautifulSoup Parser |
                 +----------+-----------+
                            |
              Extract directory and file links
                            |
                            v
                 +----------------------+
                 |      utils.py        |
                 | URL normalization    |
                 | Extension mapping    |
                 | Asset exclusion      |
                 +----------+-----------+
                            |
                            v
                 +----------------------+
                 |    database.py       |
                 | SQLite via aiosqlite |
                 | indexed_files table  |
                 | optional FTS5 index  |
                 +----------+-----------+
                            |
                            v
                 +----------------------+
                 |       app.py         |
                 | FastAPI /search API  |
                 +----------------------+
```

---

## 4. Target Repository Structure

```text
open-directory-indexer/
├── PROJECT_DEVELOPMENT_PLAN.md
├── requirements.txt
├── data/
│   └── .gitkeep
├── src/
│   ├── __init__.py
│   ├── config.py
│   ├── models.py
│   ├── utils.py
│   ├── database.py
│   ├── crawler.py
│   ├── app.py
│   └── main.py
└── tests/
    ├── __init__.py
    ├── test_utils.py
    ├── test_database.py
    └── test_api.py
```

---

## 5. Technology Stack

| Component | Technology | Purpose |
|---|---|---|
| Async HTTP client | `aiohttp` | Fetch open-directory HTML pages asynchronously |
| HTML parsing | `beautifulsoup4` | Extract anchors and malformed href paths safely |
| Database | `aiosqlite` | Asynchronous SQLite persistence |
| API framework | `FastAPI` | JSON search API |
| ASGI server | `uvicorn` | Serve FastAPI application |
| Python version | `3.11+` | Modern typing, asyncio, and performance improvements |

---

## 6. Database Schema

### 6.1 Primary Table

```sql
CREATE TABLE IF NOT EXISTS indexed_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_name TEXT NOT NULL,
    file_url TEXT NOT NULL UNIQUE,
    file_type TEXT NOT NULL,
    discovered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 6.2 Performance Index

```sql
CREATE INDEX IF NOT EXISTS idx_indexed_files_file_name
ON indexed_files(file_name);
```

### 6.3 Optional FTS5 Table

When SQLite FTS5 is available, the engine creates:

```sql
CREATE VIRTUAL TABLE IF NOT EXISTS indexed_files_fts USING fts5(
    file_name,
    file_url UNINDEXED,
    file_type UNINDEXED,
    tokenize='unicode61 remove_diacritics 2'
);
```

If FTS5 is unavailable, search falls back safely to:

```sql
SELECT file_name, file_url, file_type
FROM indexed_files
WHERE file_name LIKE '%keyword%';
```

---

## 7. API Design

### 7.1 Health Check

```http
GET /health
```

Response:

```json
{
  "status": "ok"
}
```

### 7.2 Index Statistics

```http
GET /stats
```

Example response:

```json
{
  "total_files": 12845,
  "by_type": {
    "Video": 6200,
    "Audio": 3100,
    "Document": 2200,
    "Archive": 900,
    "Executable": 445
  },
  "fts_enabled": true
}
```

### 7.3 Search Endpoint

```http
GET /search?q=ubuntu&type=archive&limit=20
```

Query parameters:

| Parameter | Required | Type | Description |
|---|---:|---|---|
| `q` | Yes | string | Keyword or partial file name |
| `type` | No | string | Category filter: `video`, `audio`, `document`, `archive`, `executable` |
| `limit` | No | integer | Maximum number of rows, default `50`, max `200` |

Example response:

```json
{
  "query": "ubuntu",
  "type": "Archive",
  "limit": 20,
  "count": 1,
  "results": [
    {
      "file_name": "ubuntu-24.04-desktop-amd64.iso",
      "file_url": "https://mirror.example.org/releases/ubuntu-24.04-desktop-amd64.iso",
      "file_type": "Archive"
    }
  ]
}
```

---

## 8. Crawler Design

### 8.1 Crawling Behavior

The crawler:

1. Accepts seed URLs representing open directories.
2. Normalizes seed URLs.
3. Fetches HTML using `aiohttp`.
4. Limits concurrent HTTP requests with an `asyncio.Semaphore`.
5. Parses anchor tags with BeautifulSoup.
6. Resolves relative links against the current URL or `<base>` tag.
7. Classifies links as directory links or file links.
8. Enqueues valid child directories.
9. Inserts valid direct file links into SQLite.
10. Skips dead domains, timeouts, SSL failures, invalid HTML, and malformed URLs.

### 8.2 Politeness Controls

- Global concurrency cap: default `10`.
- Optional delay after each successful response.
- Maximum directory count.
- Maximum file count.
- Maximum crawl depth.
- Maximum HTML payload size.
- Graceful skip behavior for non-HTML responses.

### 8.3 Link Rules

Directory links:

- End with `/`.
- Are valid absolute HTTP or HTTPS URLs.
- Are within the seed directory subtree.
- Have not already been visited.

File links:

- Do not end with `/`.
- Have a final path segment.
- Are not excluded web assets.
- Map to one of the target file categories.
- Are absolute HTTP or HTTPS URLs.

Excluded asset extensions include:

- `.html`
- `.htm`
- `.css`
- `.js`
- `.svg`
- common image formats
- common server-side script extensions

---

## 9. Extension Mapping Strategy

The mapper groups extensions into broad categories.

### 9.1 Video

Examples:

- `.mp4`
- `.mkv`
- `.avi`
- `.mov`
- `.webm`
- `.m4v`
- `.mpg`
- `.mpeg`
- `.ts`
- `.flv`
- `.wmv`

### 9.2 Audio

Examples:

- `.mp3`
- `.wav`
- `.flac`
- `.aac`
- `.ogg`
- `.opus`
- `.m4a`
- `.wma`

### 9.3 Document

Examples:

- `.pdf`
- `.epub`
- `.docx`
- `.doc`
- `.txt`
- `.rtf`
- `.odt`
- `.mobi`
- `.azw3`
- `.csv`
- `.md`
- `.djvu`

### 9.4 Archive

Examples:

- `.zip`
- `.rar`
- `.7z`
- `.tar`
- `.gz`
- `.tar.gz`
- `.bz2`
- `.xz`
- `.iso`
- `.dmg`

### 9.5 Executable

Examples:

- `.exe`
- `.msi`
- `.apk`
- `.deb`
- `.rpm`
- `.jar`
- `.sh`
- `.bat`
- `.ps1`
- `.appimage`

---

## 10. Development Roadmap

### Phase 1: Project Bootstrap

**Objective:** Create the repository, environment, and configuration foundation.

Tasks:

1. Initialize project directory.
2. Create virtual environment.
3. Add `requirements.txt`.
4. Create `src/` package layout.
5. Implement environment-driven `Settings`.
6. Add logging configuration.

Acceptance criteria:

- Python 3.11+ runs the project.
- Dependencies install cleanly.
- Settings can be overridden via environment variables and CLI arguments.

Estimated effort: `0.5 day`

---

### Phase 2: Utility Layer

**Objective:** Implement URL and extension classification logic.

Tasks:

1. Implement URL normalization.
2. Implement seed URL canonicalization.
3. Implement directory detection.
4. Implement file-name extraction.
5. Implement extension mapping.
6. Implement web-asset exclusion.
7. Implement type alias normalization.

Acceptance criteria:

- Relative links resolve correctly.
- Malformed URLs return `None` instead of raising exceptions.
- Directory links ending with `/` are detected.
- HTML, CSS, JS, and SVG assets are excluded.
- File categories are deterministic.

Estimated effort: `1 day`

---

### Phase 3: SQLite Persistence Layer

**Objective:** Implement asynchronous storage and search.

Tasks:

1. Create SQLite schema.
2. Add unique constraint on `file_url`.
3. Add index on `file_name`.
4. Add optional FTS5 table.
5. Implement insert with duplicate suppression.
6. Implement fallback search.
7. Implement statistics endpoint support.

Acceptance criteria:

- Duplicate URLs are ignored.
- Database file is created automatically.
- FTS5 is used when available.
- Search falls back to `LIKE` if FTS5 fails or is unavailable.
- Type filtering works.

Estimated effort: `1 day`

---

### Phase 4: Asynchronous Crawler

**Objective:** Implement polite asynchronous open-directory crawling.

Tasks:

1. Create `AsyncDirectoryCrawler`.
2. Add seed queue initialization.
3. Add worker pool.
4. Add semaphore-limited HTTP fetcher.
5. Add HTML size limiting.
6. Add BeautifulSoup link extraction.
7. Add directory enqueue rules.
8. Add file indexing rules.
9. Add exception handling for network failures.

Acceptance criteria:

- Maximum concurrent requests is enforced.
- Dead domains are skipped without crashing.
- Timeouts are handled gracefully.
- SSL failures are skipped.
- Malformed href values do not crash the parser.
- Directory traversal remains within seed subtree.
- Crawler stops cleanly when queue is drained.

Estimated effort: `1.5 days`

---

### Phase 5: FastAPI Search Service

**Objective:** Expose indexed data through a JSON API.

Tasks:

1. Create FastAPI application factory.
2. Add `/health`.
3. Add `/stats`.
4. Add `/search`.
5. Validate query parameters.
6. Normalize type filters.
7. Return structured JSON responses.
8. Convert database errors into HTTP 500 responses.

Acceptance criteria:

- `/search?q=keyword` returns JSON.
- `/search?q=keyword&type=video` filters correctly.
- Invalid type filters return HTTP 400.
- Empty results return valid JSON with `count: 0`.
- API does not depend on UI assets.

Estimated effort: `0.5 day`

---

### Phase 6: Main Runner

**Objective:** Run crawler and API together.

Tasks:

1. Parse CLI arguments.
2. Combine CLI and environment seed URLs.
3. Initialize database.
4. Start background crawl task.
5. Start Uvicorn server.
6. Cancel crawler cleanly on shutdown.

Acceptance criteria:

- One command starts both API and crawler.
- API remains available while crawl is running.
- Ctrl+C shuts down cleanly.
- Database connection is closed on exit.

Estimated effort: `0.5 day`

---

### Phase 7: Testing and Hardening

**Objective:** Validate edge cases and improve reliability.

Tasks:

1. Unit-test URL normalization.
2. Unit-test extension mapping.
3. Unit-test search fallback.
4. Integration-test FastAPI endpoint.
5. Test malformed HTML snippets.
6. Test duplicate file URL insertion.
7. Test invalid type filters.
8. Test timeout and dead-host behavior using mocked responses.

Acceptance criteria:

- Test suite passes.
- No unhandled exceptions from malformed input.
- Search endpoint remains stable under invalid queries.
- Crawler does not deadlock when queue becomes empty.

Estimated effort: `1 day`

---

### Phase 8: Performance Tuning

**Objective:** Improve search and crawl throughput.

Tasks:

1. Prefer FTS5 when available.
2. Use WAL journal mode.
3. Batch commits where appropriate.
4. Limit HTML payload size.
5. Use chunked response reading.
6. Use `asyncio.to_thread` for BeautifulSoup parsing.
7. Tune `max_concurrent_requests`.
8. Tune SQLite cache size if needed.

Acceptance criteria:

- Search remains responsive while crawling.
- SQLite does not become locked under normal write volume.
- Memory usage remains bounded.
- Crawler does not fetch excessively large HTML documents.

Estimated effort: `0.5 day`

---

## 11. Edge-Case Handling Matrix

| Edge Case | Handling Strategy |
|---|---|
| Dead domain | Catch `aiohttp.ClientError`, skip URL |
| DNS failure | Catch client/network exceptions, skip URL |
| Timeout | Catch `asyncio.TimeoutError`, skip URL |
| SSL certificate failure | Catch `ssl.SSLError`, skip URL |
| Non-200 response | Skip and log at debug level |
| Non-HTML response | Skip content |
| Malformed href | Return `None` from URL normalization |
| Relative href | Resolve against current URL or base tag |
| Duplicate file URL | `INSERT OR IGNORE` with unique constraint |
| Duplicate directory URL | In-memory visited set |
| Parent directory link | Subtree restriction prevents upward crawling |
| Query-string sort links | Directory canonicalization strips query |
| Missing file name | Skip file |
| Unknown file extension | Skip file for target index |
| HTML parse failure | Return empty link list |
| Oversized HTML page | Abort reading and skip URL |
| FTS5 unavailable | Fall back to LIKE query |
| Invalid FTS query | Fall back to LIKE query |
| Invalid API type | Return HTTP 400 |

---

## 12. Testing Strategy

### 12.1 Unit Tests

Focus areas:

- `split_extension`
- `get_file_type`
- `normalize_url`
- `canonicalize_seed_url`
- `is_directory_url`
- `should_index_file`
- `normalize_type`
- `_escape_like`
- `_build_fts_query`

### 12.2 Database Tests

Focus areas:

- Schema creation.
- Duplicate URL suppression.
- Type filtering.
- FTS fallback behavior.
- Statistics aggregation.

### 12.3 API Tests

Focus areas:

- Successful search.
- Empty search.
- Missing query parameter.
- Invalid type filter.
- Limit validation.
- Health and stats endpoints.

### 12.4 Crawler Tests

Use mocked `aiohttp` responses for:

- HTML page with relative links.
- Page with `<base href>`.
- Page with malformed anchors.
- Directory page with parent links.
- File page with excluded assets.
- Dead host simulation.
- Timeout simulation.
- SSL failure simulation.

---

## 13. Security and Ethics

### 13.1 Crawling Ethics

- Do not slam remote servers.
- Keep default concurrency at `10` or lower.
- Use a descriptive `User-Agent`.
- Add request delay.
- Prefer crawl limits.
- Avoid recursive crawling outside seed subtree by default.
- Respect site terms of service where applicable.

### 13.2 Security Controls

- Validate URL schemes.
- Allow only HTTP and HTTPS.
- Strip fragments.
- Normalize paths.
- Prevent `mailto:`, `javascript:`, and `tel:` links.
- Limit HTML payload size.
- Avoid storing request bodies.
- Use parameterized SQL queries only.
- Escape LIKE wildcards.
- Sanitize FTS query tokens.

---

## 14. Deployment Plan

### 14.1 Local Development

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

python src/main.py \
  "https://mirror.example.org/pub/" \
  "https://files.example.net/open-directory/"
```

### 14.2 Production-Style Service

Use a process manager such as `systemd`, `supervisor`, or container restart policy.

Example command:

```bash
python src/main.py \
  --host 0.0.0.0 \
  --port 8000 \
  --db data/indexer.db \
  "https://mirror.example.org/pub/"
```

### 14.3 Environment Variables

| Variable | Default | Purpose |
|---|---:|---|
| `INDEXER_DB_PATH` | `data/indexer.db` | SQLite database location |
| `INDEXER_HOST` | `127.0.0.1` | API bind host |
| `INDEXER_PORT` | `8000` | API bind port |
| `INDEXER_MAX_CONCURRENT_REQUESTS` | `10` | Crawler concurrency cap |
| `INDEXER_REQUEST_TIMEOUT_SECONDS` | `20` | HTTP timeout |
| `INDEXER_REQUEST_DELAY_SECONDS` | `0.25` | Delay after successful fetch |
| `INDEXER_USER_AGENT` | `OpenDirectoryFileIndexer/1.0` | User agent header |
| `INDEXER_MAX_DIRECTORIES` | `5000` | Directory crawl cap |
| `INDEXER_MAX_FILES` | `200000` | File insert cap |
| `INDEXER_MAX_DEPTH` | `5` | Crawl depth cap |
| `INDEXER_MAX_HTML_BYTES` | `5242880` | HTML payload cap |
| `INDEXER_VERIFY_SSL` | `1` | Enable or disable SSL verification |
| `INDEXER_SEED_URLS` | empty | Comma-separated seed URLs |

---

## 15. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---:|---:|---|
| Remote servers block crawler | Medium | Medium | Polite delays, low concurrency, configurable user agent |
| SQLite write contention | Medium | Medium | WAL mode, write lock, bounded crawler concurrency |
| FTS5 unavailable | Low | Low | LIKE fallback |
| Malformed HTML crashes parser | Low | High | Exception-safe parsing and URL normalization |
| Infinite crawl expansion | Medium | High | Depth, directory cap, subtree restriction |
| Memory growth from visited directories | Medium | Medium | Directory cap and bounded queue |
| Legal concerns over indexing | Medium | High | Operator responsibility, seed control, no content hosting |
| Large HTML pages exhaust memory | Low | High | Chunked read and max byte limit |

---

## 16. Definition of Done

The project is complete when:

1. The crawler can start from seed URLs.
2. Direct file links are extracted and categorized.
3. Files are stored in SQLite with unique URLs.
4. Search endpoint returns JSON results.
5. Type filtering works.
6. FTS5 is used when available.
7. LIKE fallback works when FTS5 is unavailable.
8. Dead links, timeouts, and SSL failures are skipped safely.
9. No pseudocode remains in shipped modules.
10. The API can run while crawling continues in the background.
11. The code follows PEP8 style and uses explicit type hints.
12. The project can be started with one command.

---

# Appendix A: Reference Implementation

This appendix contains a complete backend reference implementation for the plan.

---

## A.1 `requirements.txt`

```text
aiohttp>=3.9,<4
beautifulsoup4>=4.12,<5
aiosqlite>=0.20,<1
fastapi>=0.111,<1
uvicorn[standard]>=0.30,<1
```

---

## A.2 `src/config.py`

```python
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path


def _env_seed_urls() -> tuple[str, ...]:
    raw = os.getenv("INDEXER_SEED_URLS", "")
    if not raw:
        return ()

    parts = raw.replace(";", ",").split(",")
    return tuple(part.strip() for part in parts if part.strip())


def _env_bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default

    return raw.strip().lower() not in {"0", "false", "no", "off"}


@dataclass(frozen=True, slots=True)
class Settings:
    database_path: Path = field(
        default_factory=lambda: Path(os.getenv("INDEXER_DB_PATH", "data/indexer.db"))
    )
    host: str = field(
        default_factory=lambda: os.getenv("INDEXER_HOST", "127.0.0.1")
    )
    port: int = field(
        default_factory=lambda: int(os.getenv("INDEXER_PORT", "8000"))
    )
    max_concurrent_requests: int = field(
        default_factory=lambda: int(os.getenv("INDEXER_MAX_CONCURRENT_REQUESTS", "10"))
    )
    request_timeout_seconds: float = field(
        default_factory=lambda: float(os.getenv("INDEXER_REQUEST_TIMEOUT_SECONDS", "20"))
    )
    request_delay_seconds: float = field(
        default_factory=lambda: float(os.getenv("INDEXER_REQUEST_DELAY_SECONDS", "0.25"))
    )
    user_agent: str = field(
        default_factory=lambda: os.getenv(
            "INDEXER_USER_AGENT",
            "OpenDirectoryFileIndexer/1.0",
        )
    )
    max_directories: int = field(
        default_factory=lambda: int(os.getenv("INDEXER_MAX_DIRECTORIES", "5000"))
    )
    max_files: int = field(
        default_factory=lambda: int(os.getenv("INDEXER_MAX_FILES", "200000"))
    )
    max_depth: int = field(
        default_factory=lambda: int(os.getenv("INDEXER_MAX_DEPTH", "5"))
    )
    max_html_bytes: int = field(
        default_factory=lambda: int(
            os.getenv("INDEXER_MAX_HTML_BYTES", str(5 * 1024 * 1024))
        )
    )
    verify_ssl: bool = field(
        default_factory=lambda: _env_bool("INDEXER_VERIFY_SSL", True)
    )
    allowed_schemes: tuple[str, ...] = ("http", "https")
    seed_urls: tuple[str, ...] = field(default_factory=_env_seed_urls)
```

---

## A.3 `src/models.py`

```python
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class IndexedFile:
    file_name: str
    file_url: str
    file_type: str
    id: int | None = None
    discovered_at: str | None = None


@dataclass(slots=True)
class CrawlStats:
    directories_queued: int = 0
    directories_crawled: int = 0
    files_discovered: int = 0
    files_indexed: int = 0
    errors: int = 0

    def as_dict(self) -> dict[str, int]:
        return {
            "directories_queued": self.directories_queued,
            "directories_crawled": self.directories_crawled,
            "files_discovered": self.files_discovered,
            "files_indexed": self.files_indexed,
            "errors": self.errors,
        }
```

---

## A.4 `src/utils.py`

```python
from __future__ import annotations

import posixpath
import re
from typing import Final
from urllib.parse import unquote, urljoin, urlsplit, urlunsplit

FILE_TYPE_VIDEO: Final[str] = "Video"
FILE_TYPE_AUDIO: Final[str] = "Audio"
FILE_TYPE_DOCUMENT: Final[str] = "Document"
FILE_TYPE_ARCHIVE: Final[str] = "Archive"
FILE_TYPE_EXECUTABLE: Final[str] = "Executable"
FILE_TYPE_OTHER: Final[str] = "Other"

_ALLOWED_SCHEMES: Final[frozenset[str]] = frozenset({"http", "https"})

_EXTENSION_CATEGORY_MAP: Final[dict[str, str]] = {
    # Video
    ".mp4": FILE_TYPE_VIDEO,
    ".m4v": FILE_TYPE_VIDEO,
    ".mkv": FILE_TYPE_VIDEO,
    ".avi": FILE_TYPE_VIDEO,
    ".mov": FILE_TYPE_VIDEO,
    ".webm": FILE_TYPE_VIDEO,
    ".mpg": FILE_TYPE_VIDEO,
    ".mpeg": FILE_TYPE_VIDEO,
    ".ts": FILE_TYPE_VIDEO,
    ".flv": FILE_TYPE_VIDEO,
    ".wmv": FILE_TYPE_VIDEO,
    ".3gp": FILE_TYPE_VIDEO,
    # Audio
    ".mp3": FILE_TYPE_AUDIO,
    ".wav": FILE_TYPE_AUDIO,
    ".flac": FILE_TYPE_AUDIO,
    ".aac": FILE_TYPE_AUDIO,
    ".ogg": FILE_TYPE_AUDIO,
    ".opus": FILE_TYPE_AUDIO,
    ".m4a": FILE_TYPE_AUDIO,
    ".wma": FILE_TYPE_AUDIO,
    ".mid": FILE_TYPE_AUDIO,
    ".midi": FILE_TYPE_AUDIO,
    # Document
    ".pdf": FILE_TYPE_DOCUMENT,
    ".epub": FILE_TYPE_DOCUMENT,
    ".mobi": FILE_TYPE_DOCUMENT,
    ".azw": FILE_TYPE_DOCUMENT,
    ".azw3": FILE_TYPE_DOCUMENT,
    ".doc": FILE_TYPE_DOCUMENT,
    ".docx": FILE_TYPE_DOCUMENT,
    ".txt": FILE_TYPE_DOCUMENT,
    ".rtf": FILE_TYPE_DOCUMENT,
    ".odt": FILE_TYPE_DOCUMENT,
    ".xls": FILE_TYPE_DOCUMENT,
    ".xlsx": FILE_TYPE_DOCUMENT,
    ".csv": FILE_TYPE_DOCUMENT,
    ".ppt": FILE_TYPE_DOCUMENT,
    ".pptx": FILE_TYPE_DOCUMENT,
    ".md": FILE_TYPE_DOCUMENT,
    ".djvu": FILE_TYPE_DOCUMENT,
    # Archive
    ".zip": FILE_TYPE_ARCHIVE,
    ".rar": FILE_TYPE_ARCHIVE,
    ".7z": FILE_TYPE_ARCHIVE,
    ".tar": FILE_TYPE_ARCHIVE,
    ".gz": FILE_TYPE_ARCHIVE,
    ".tar.gz": FILE_TYPE_ARCHIVE,
    ".tgz": FILE_TYPE_ARCHIVE,
    ".bz2": FILE_TYPE_ARCHIVE,
    ".tar.bz2": FILE_TYPE_ARCHIVE,
    ".xz": FILE_TYPE_ARCHIVE,
    ".tar.xz": FILE_TYPE_ARCHIVE,
    ".zst": FILE_TYPE_ARCHIVE,
    ".tar.zst": FILE_TYPE_ARCHIVE,
    ".iso": FILE_TYPE_ARCHIVE,
    ".dmg": FILE_TYPE_ARCHIVE,
    ".cab": FILE_TYPE_ARCHIVE,
    # Executable / software
    ".exe": FILE_TYPE_EXECUTABLE,
    ".msi": FILE_TYPE_EXECUTABLE,
    ".apk": FILE_TYPE_EXECUTABLE,
    ".deb": FILE_TYPE_EXECUTABLE,
    ".rpm": FILE_TYPE_EXECUTABLE,
    ".jar": FILE_TYPE_EXECUTABLE,
    ".sh": FILE_TYPE_EXECUTABLE,
    ".bash": FILE_TYPE_EXECUTABLE,
    ".bat": FILE_TYPE_EXECUTABLE,
    ".cmd": FILE_TYPE_EXECUTABLE,
    ".ps1": FILE_TYPE_EXECUTABLE,
    ".appimage": FILE_TYPE_EXECUTABLE,
    ".bin": FILE_TYPE_EXECUTABLE,
}

_EXCLUDED_ASSET_EXTENSIONS: Final[frozenset[str]] = frozenset(
    {
        ".html",
        ".htm",
        ".xhtml",
        ".shtml",
        ".mhtml",
        ".css",
        ".js",
        ".mjs",
        ".cjs",
        ".svg",
        ".png",
        ".jpg",
        ".jpeg",
        ".gif",
        ".ico",
        ".webp",
        ".bmp",
        ".tif",
        ".tiff",
        ".php",
        ".asp",
        ".aspx",
        ".jsp",
        ".cgi",
        ".pl",
        ".py",
        ".rb",
        ".cfm",
        ".xml",
        ".json",
    }
)

_TYPE_ALIASES: Final[dict[str, str]] = {
    "video": FILE_TYPE_VIDEO,
    "videos": FILE_TYPE_VIDEO,
    "audio": FILE_TYPE_AUDIO,
    "audios": FILE_TYPE_AUDIO,
    "sound": FILE_TYPE_AUDIO,
    "music": FILE_TYPE_AUDIO,
    "document": FILE_TYPE_DOCUMENT,
    "documents": FILE_TYPE_DOCUMENT,
    "doc": FILE_TYPE_DOCUMENT,
    "docs": FILE_TYPE_DOCUMENT,
    "ebook": FILE_TYPE_DOCUMENT,
    "ebooks": FILE_TYPE_DOCUMENT,
    "book": FILE_TYPE_DOCUMENT,
    "books": FILE_TYPE_DOCUMENT,
    "archive": FILE_TYPE_ARCHIVE,
    "archives": FILE_TYPE_ARCHIVE,
    "compressed": FILE_TYPE_ARCHIVE,
    "archive software": FILE_TYPE_ARCHIVE,
    "executable": FILE_TYPE_EXECUTABLE,
    "executables": FILE_TYPE_EXECUTABLE,
    "software": FILE_TYPE_EXECUTABLE,
    "application": FILE_TYPE_EXECUTABLE,
    "applications": FILE_TYPE_EXECUTABLE,
    "app": FILE_TYPE_EXECUTABLE,
    "apps": FILE_TYPE_EXECUTABLE,
    "binary": FILE_TYPE_EXECUTABLE,
    "other": FILE_TYPE_OTHER,
}


def split_extension(file_name: str) -> str:
    name = file_name.strip().lower()
    if not name:
        return ""

    compound_extensions = (
        ".tar.gz",
        ".tar.bz2",
        ".tar.xz",
        ".tar.zst",
    )
    for compound in compound_extensions:
        if name.endswith(compound):
            return compound

    dot_index = name.rfind(".")
    if dot_index <= 0 or dot_index == len(name) - 1:
        return ""

    return name[dot_index:]


def get_file_type(file_name: str) -> str:
    extension = split_extension(file_name)
    return _EXTENSION_CATEGORY_MAP.get(extension, FILE_TYPE_OTHER)


def get_file_name(url: str) -> str:
    parsed = urlsplit(url)
    path = unquote(parsed.path)
    if not path or path == "/":
        return ""

    name = path.rstrip("/").rsplit("/", 1)[-1]
    return name.strip()


def normalize_url(base_url: str, href: str) -> str | None:
    cleaned_href = href.strip()
    if not cleaned_href:
        return None

    lowered_href = cleaned_href.lower()
    if lowered_href.startswith(
        (
            "mailto:",
            "javascript:",
            "tel:",
            "ftp:",
            "data:",
            "#",
        )
    ):
        return None

    try:
        joined = urljoin(base_url, cleaned_href)
        parsed = urlsplit(joined)
    except ValueError:
        return None

    if parsed.scheme not in _ALLOWED_SCHEMES or not parsed.netloc:
        return None

    path = parsed.path or "/"
    if not path.startswith("/"):
        path = "/" + path

    ends_with_slash = path.endswith("/")
    normalized_path = posixpath.normpath(path)

    if normalized_path in {".", ""}:
        normalized_path = "/"

    if not normalized_path.startswith("/"):
        normalized_path = "/" + normalized_path

    if ends_with_slash and not normalized_path.endswith("/"):
        normalized_path += "/"

    return urlunsplit(
        (
            parsed.scheme.lower(),
            parsed.netloc.lower(),
            normalized_path,
            parsed.query,
            "",
        )
    )


def canonical_directory_url(url: str) -> str:
    parsed = urlsplit(url)
    path = parsed.path or "/"

    if not path.startswith("/"):
        path = "/" + path

    if not path.endswith("/"):
        last_segment = unquote(path.rsplit("/", 1)[-1])
        if not split_extension(last_segment):
            path += "/"

    return urlunsplit(
        (
            parsed.scheme.lower(),
            parsed.netloc.lower(),
            path,
            "",
            "",
        )
    )


def canonicalize_seed_url(url: str) -> str | None:
    cleaned = url.strip()
    if not cleaned:
        return None

    try:
        parsed = urlsplit(cleaned)
    except ValueError:
        return None

    if parsed.scheme not in _ALLOWED_SCHEMES or not parsed.netloc:
        return None

    path = parsed.path or "/"
    if not path.startswith("/"):
        path = "/" + path

    if not path.endswith("/"):
        last_segment = unquote(path.rsplit("/", 1)[-1])
        if not split_extension(last_segment):
            path += "/"

    return urlunsplit(
        (
            parsed.scheme.lower(),
            parsed.netloc.lower(),
            path,
            "",
            "",
        )
    )


def is_directory_url(url: str) -> bool:
    parsed = urlsplit(url)
    path = parsed.path or "/"
    return path.endswith("/")


def is_within_directory(root_url: str, target_url: str) -> bool:
    root = urlsplit(canonical_directory_url(root_url))
    target = urlsplit(canonical_directory_url(target_url))

    if root.scheme != target.scheme or root.netloc != target.netloc:
        return False

    root_path = root.path or "/"
    target_path = target.path or "/"

    if not root_path.endswith("/"):
        root_path += "/"

    if not target_path.endswith("/"):
        target_path += "/"

    return target_path.startswith(root_path)


def is_excluded_asset(url: str) -> bool:
    file_name = get_file_name(url)
    if not file_name:
        return True

    lowered_name = file_name.lower()
    if lowered_name in {".ds_store", "thumbs.db"}:
        return True

    extension = split_extension(file_name)
    return extension in _EXCLUDED_ASSET_EXTENSIONS


def should_index_file(url: str) -> bool:
    if is_directory_url(url):
        return False

    parsed = urlsplit(url)
    path = parsed.path or "/"
    if path == "/":
        return False

    file_name = get_file_name(url)
    if not file_name:
        return False

    if file_name.lower() in {".", "..", "parent directory"}:
        return False

    if is_excluded_asset(url):
        return False

    return True


def normalize_type(raw_type: str | None) -> str | None:
    if raw_type is None:
        return None

    cleaned = raw_type.strip().lower()
    cleaned = cleaned.replace("_", " ").replace("-", " ").replace("/", " ")
    cleaned = re.sub(r"\s+", " ", cleaned).strip()

    if not cleaned:
        return None

    return _TYPE_ALIASES.get(cleaned)
```

---

## A.5 `src/database.py`

```python
from __future__ import annotations

import asyncio
import logging
import re
import sqlite3
from pathlib import Path
from typing import Any, Final

import aiosqlite

from utils import normalize_type

_LOGGER: Final = logging.getLogger("indexer.database")

_CREATE_TABLE_SQL: Final[str] = """
CREATE TABLE IF NOT EXISTS indexed_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_name TEXT NOT NULL,
    file_url TEXT NOT NULL UNIQUE,
    file_type TEXT NOT NULL,
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
    def __init__(self, path: Path) -> None:
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
    ) -> bool:
        connection = self._require_connection()
        normalized_type = normalize_type(file_type) or file_type

        async with self._lock:
            cursor = await connection.execute(
                """
                INSERT OR IGNORE INTO indexed_files (
                    file_name,
                    file_url,
                    file_type
                )
                VALUES (?, ?, ?);
                """,
                (file_name, file_url, normalized_type),
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
                            i.file_type
                        FROM indexed_files_fts AS f
                        JOIN indexed_files AS i ON i.id = f.rowid
                        WHERE f MATCH ?
                          AND (? IS NULL OR i.file_type = ?)
                        ORDER BY f.rank
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
                SELECT file_name, file_url, file_type
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
                SELECT file_name, file_url, file_type
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

    async def _initialize_schema(self) -> None:
        connection = self._require_connection()
        await connection.execute(_CREATE_TABLE_SQL)
        await connection.execute(_CREATE_INDEX_SQL)

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
```

---

## A.6 `src/crawler.py`

```python
from __future__ import annotations

import asyncio
import logging
import ssl
from collections.abc import Sequence
from typing import Final

import aiohttp
from bs4 import BeautifulSoup

from config import Settings
from database import Database
from models import CrawlStats
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

_LOGGER: Final = logging.getLogger("indexer.crawler")


class AsyncDirectoryCrawler:
    def __init__(self, settings: Settings, database: Database) -> None:
        self._settings = settings
        self._database = database
        self._semaphore = asyncio.Semaphore(settings.max_concurrent_requests)
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

        self._stats.directories_crawled += 1

        html = await self._fetch_html(session, url)
        if html is None:
            return

        links = await asyncio.to_thread(self._extract_links, html, url)

        for link in links:
            if is_directory_url(link):
                self._maybe_enqueue_directory(link, depth, root, queue)
            elif should_index_file(link):
                await self._maybe_index_file(link)

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

    async def _maybe_index_file(self, link: str) -> None:
        if self._stats.files_indexed >= self._settings.max_files:
            return

        file_name = get_file_name(link)
        if not file_name:
            return

        file_type = get_file_type(file_name)
        if file_type == "Other":
            return

        self._stats.files_discovered += 1

        try:
            inserted = await self._database.insert_file(
                file_name=file_name,
                file_url=link,
                file_type=file_type,
            )
        except Exception:
            _LOGGER.exception("Failed to insert file: %s", link)
            self._stats.errors += 1
            return

        if inserted:
            self._stats.files_indexed += 1

    async def _fetch_html(
        self,
        session: aiohttp.ClientSession,
        url: str,
    ) -> str | None:
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
```

---

## A.7 `src/app.py`

```python
from __future__ import annotations

import logging
from typing import Annotated, Any, Final

from fastapi import FastAPI, HTTPException, Query

from config import Settings
from database import Database
from utils import normalize_type

_LOGGER: Final = logging.getLogger("indexer.api")


def create_app(database: Database, settings: Settings) -> FastAPI:
    app = FastAPI(
        title="Open Directory File Indexer API",
        version="1.0.0",
        description="Search indexed direct file links from open directories.",
    )

    app.state.database = database
    app.state.settings = settings

    @app.get("/health", tags=["status"])
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/stats", tags=["status"])
    async def stats() -> dict[str, Any]:
        try:
            return await database.get_stats()
        except Exception as exc:
            _LOGGER.exception("Failed to read indexer statistics.")
            raise HTTPException(
                status_code=500,
                detail="Unable to read indexer statistics.",
            ) from exc

    @app.get("/search", tags=["search"])
    async def search(
        q: Annotated[
            str,
            Query(
                min_length=1,
                max_length=200,
                description="Keyword or partial file name.",
            ),
        ],
        type: Annotated[
            str | None,
            Query(
                description=(
                    "Optional category filter: video, audio, document, "
                    "archive, executable."
                ),
            ),
        ] = None,
        limit: Annotated[
            int,
            Query(
                ge=1,
                le=200,
                description="Maximum number of results to return.",
            ),
        ] = 50,
    ) -> dict[str, Any]:
        canonical_type = normalize_type(type) if type is not None else None

        if type is not None and canonical_type is None:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Invalid type filter. Expected one of: video, audio, "
                    "document, archive, executable."
                ),
            )

        try:
            results = await database.search(
                query=q,
                type_filter=canonical_type,
                limit=limit,
            )
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        except Exception as exc:
            _LOGGER.exception("Search request failed.")
            raise HTTPException(
                status_code=500,
                detail="Search request failed.",
            ) from exc

        return {
            "query": q,
            "type": canonical_type,
            "limit": limit,
            "count": len(results),
            "results": results,
        }

    return app
```

---

## A.8 `src/main.py`

```python
from __future__ import annotations

import argparse
import asyncio
import contextlib
import logging
from dataclasses import replace
from pathlib import Path

import uvicorn

from app import create_app
from config import Settings
from crawler import AsyncDirectoryCrawler
from database import Database


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Asynchronous open-directory file indexer and FastAPI search service."
        )
    )

    parser.add_argument(
        "seed_urls",
        nargs="*",
        help="Initial open-directory seed URLs.",
    )
    parser.add_argument(
        "--host",
        default=None,
        help="API bind host.",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=None,
        help="API bind port.",
    )
    parser.add_argument(
        "--db",
        default=None,
        help="SQLite database file path.",
    )
    parser.add_argument(
        "--max-concurrent-requests",
        type=int,
        default=None,
        help="Maximum concurrent crawl requests.",
    )
    parser.add_argument(
        "--max-depth",
        type=int,
        default=None,
        help="Maximum crawl depth.",
    )
    parser.add_argument(
        "--max-directories",
        type=int,
        default=None,
        help="Maximum number of directories to crawl.",
    )
    parser.add_argument(
        "--max-files",
        type=int,
        default=None,
        help="Maximum number of files to index.",
    )

    return parser.parse_args()


def build_settings(args: argparse.Namespace) -> tuple[Settings, tuple[str, ...]]:
    settings = Settings()
    overrides: dict[str, object] = {}

    if args.host is not None:
        overrides["host"] = args.host

    if args.port is not None:
        overrides["port"] = args.port

    if args.db is not None:
        overrides["database_path"] = Path(args.db)

    if args.max_concurrent_requests is not None:
        overrides["max_concurrent_requests"] = args.max_concurrent_requests

    if args.max_depth is not None:
        overrides["max_depth"] = args.max_depth

    if args.max_directories is not None:
        overrides["max_directories"] = args.max_directories

    if args.max_files is not None:
        overrides["max_files"] = args.max_files

    if overrides:
        settings = replace(settings, **overrides)

    unique_seeds: list[str] = []

    for seed in args.seed_urls:
        if seed not in unique_seeds:
            unique_seeds.append(seed)

    for seed in settings.seed_urls:
        if seed not in unique_seeds:
            unique_seeds.append(seed)

    return settings, tuple(unique_seeds)


def _log_crawl_result(task: asyncio.Task) -> None:
    logger = logging.getLogger("indexer.main")

    try:
        stats = task.result()
        logger.info("Crawl completed: %s", stats.as_dict())
    except asyncio.CancelledError:
        logger.info("Crawl task cancelled.")
    except Exception:
        logger.exception("Crawl task failed.")


async def run(seed_urls: tuple[str, ...], settings: Settings) -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    logger = logging.getLogger("indexer.main")

    if not seed_urls:
        logger.warning(
            "No seed URLs supplied. The API will start, but crawling will not "
            "add new items unless the database already contains data."
        )

    database = Database(settings.database_path)
    await database.connect()

    crawler = AsyncDirectoryCrawler(settings=settings, database=database)
    app = create_app(database=database, settings=settings)

    config = uvicorn.Config(
        app=app,
        host=settings.host,
        port=settings.port,
        log_level="info",
        lifespan="off",
    )
    server = uvicorn.Server(config)

    crawl_task = asyncio.create_task(
        crawler.crawl_seeds(seed_urls),
        name="background-crawl",
    )
    crawl_task.add_done_callback(_log_crawl_result)

    try:
        await server.serve()
    finally:
        if not crawl_task.done():
            crawl_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await crawl_task

        await database.close()


def main() -> None:
    args = parse_args()
    settings, seed_urls = build_settings(args)
    asyncio.run(run(seed_urls, settings))


if __name__ == "__main__":
    main()
```

---

## 17. Runbook

### 17.1 Install

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 17.2 Run with Seed URLs

```bash
python src/main.py \
  "https://mirror.example.org/pub/" \
  "https://files.example.net/open-directory/"
```

### 17.3 Query the API

```bash
curl "http://127.0.0.1:8000/search?q=ubuntu"
```

```bash
curl "http://127.0.0.1:8000/search?q=ubuntu&type=archive&limit=20"
```

```bash
curl "http://127.0.0.1:8000/stats"
```

---

## 18. Future Extension Backlog

1. robots.txt parser and enforcement.
2. Per-host rate limiting.
3. Proxy pool integration.
4. Content-hash deduplication.
5. PostgreSQL or DuckDB export for analytics.
6. Admin API for pause, resume, and crawl-job management.
7. Background revalidation of dead file URLs.
8. File-size extraction from `Content-Length` headers.
9. Language detection for document files.
10. Distributed crawler coordination using Redis.
