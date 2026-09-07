from __future__ import annotations

import argparse
import asyncio
import contextlib
import logging
import sys
from dataclasses import replace
from pathlib import Path

# Ensure src directory is in sys.path when executed directly
_CURRENT_DIR = Path(__file__).resolve().parent
if str(_CURRENT_DIR) not in sys.path:
    sys.path.insert(0, str(_CURRENT_DIR))

import uvicorn

try:
    from app import create_app
    from config import Settings
    from crawler import AsyncDirectoryCrawler
    from database import Database
except ImportError:
    from src.app import create_app
    from src.config import Settings
    from src.crawler import AsyncDirectoryCrawler
    from src.database import Database


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
    parser.add_argument(
        "--no-robots",
        action="store_true",
        default=False,
        help="Disable robots.txt compliance checking.",
    )
    parser.add_argument(
        "--per-host-delay",
        type=float,
        default=None,
        help="Per-host delay between requests in seconds.",
    )
    parser.add_argument(
        "--no-file-size",
        action="store_true",
        default=False,
        help="Disable file size extraction via HTTP HEAD requests.",
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

    if getattr(args, "no_robots", False):
        overrides["obey_robots_txt"] = False

    if getattr(args, "per_host_delay", None) is not None:
        overrides["per_host_delay_seconds"] = args.per_host_delay

    if getattr(args, "no_file_size", False):
        overrides["fetch_file_size"] = False

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
    app = create_app(database=database, settings=settings, crawler=crawler)

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
