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
    obey_robots_txt: bool = field(
        default_factory=lambda: _env_bool("INDEXER_OBEY_ROBOTS_TXT", True)
    )
    per_host_delay_seconds: float = field(
        default_factory=lambda: float(os.getenv("INDEXER_PER_HOST_DELAY_SECONDS", "0.5"))
    )
    fetch_file_size: bool = field(
        default_factory=lambda: _env_bool("INDEXER_FETCH_FILE_SIZE", True)
    )
    head_timeout_seconds: float = field(
        default_factory=lambda: float(os.getenv("INDEXER_HEAD_TIMEOUT_SECONDS", "5.0"))
    )
    allowed_schemes: tuple[str, ...] = ("http", "https")
    seed_urls: tuple[str, ...] = field(default_factory=_env_seed_urls)
