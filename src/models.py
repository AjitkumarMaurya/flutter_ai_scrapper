from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class IndexedFile:
    file_name: str
    file_url: str
    file_type: str
    file_size_bytes: int | None = None
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
