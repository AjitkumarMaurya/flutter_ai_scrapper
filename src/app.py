from __future__ import annotations

import asyncio
import logging
from typing import Annotated, Any, Final

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

try:
    from config import Settings
    from crawler import AsyncDirectoryCrawler
    from dashboard_html import DASHBOARD_HTML
    from database import Database
    from utils import normalize_type
except ImportError:
    from src.config import Settings
    from src.crawler import AsyncDirectoryCrawler
    from src.dashboard_html import DASHBOARD_HTML
    from src.database import Database
    from src.utils import normalize_type

_LOGGER: Final = logging.getLogger("indexer.api")


class SqlQueryRequest(BaseModel):
    query: str = Field(..., description="SQL SELECT query to execute on SQLite.")
    limit: int = Field(default=100, ge=1, le=500, description="Maximum number of rows to return.")


class CrawlRequest(BaseModel):
    seed_url: str = Field(..., description="Open directory URL to start crawling.")
    max_depth: int = Field(default=1, ge=0, le=5, description="Maximum depth to crawl.")


def create_app(
    database: Database,
    settings: Settings,
    crawler: AsyncDirectoryCrawler | None = None,
) -> FastAPI:
    app = FastAPI(
        title="Open Directory File Indexer API & Playground",
        version="1.1.0",
        description="Search indexed direct file links from open directories and interactive playground.",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.state.database = database
    app.state.settings = settings
    app.state.crawler = crawler

    @app.get("/", response_class=HTMLResponse, tags=["playground"])
    @app.get("/playground", response_class=HTMLResponse, tags=["playground"])
    async def playground() -> HTMLResponse:
        return HTMLResponse(DASHBOARD_HTML)

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

    @app.post("/api/sql", tags=["playground"])
    async def run_sql(body: SqlQueryRequest) -> dict[str, Any]:
        try:
            return await database.execute_sql(query=body.query, max_rows=body.limit)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        except Exception as exc:
            _LOGGER.exception("SQL execution failed.")
            raise HTTPException(
                status_code=500,
                detail=f"SQL error: {exc}",
            ) from exc

    @app.post("/api/crawl", tags=["playground"])
    async def trigger_crawl(body: CrawlRequest) -> dict[str, Any]:
        active_crawler = app.state.crawler
        if active_crawler is None:
            active_crawler = AsyncDirectoryCrawler(settings=settings, database=database)
            app.state.crawler = active_crawler

        # Launch crawl in background
        asyncio.create_task(active_crawler.crawl_seeds([body.seed_url]))

        return {
            "status": "crawling_started",
            "seed_url": body.seed_url,
            "max_depth": body.max_depth,
        }

    return app
