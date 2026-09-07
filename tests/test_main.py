from __future__ import annotations

import argparse
from pathlib import Path

from main import build_settings, parse_args


def test_build_settings_overrides() -> None:
    args = argparse.Namespace(
        seed_urls=["https://mirror.example.org/pub/"],
        host="0.0.0.0",
        port=9000,
        db="custom/path.db",
        max_concurrent_requests=15,
        max_depth=3,
        max_directories=1000,
        max_files=50000,
        no_robots=True,
        per_host_delay=1.5,
        no_file_size=True,
    )
    settings, seeds = build_settings(args)

    assert settings.host == "0.0.0.0"
    assert settings.port == 9000
    assert settings.database_path == Path("custom/path.db")
    assert settings.max_concurrent_requests == 15
    assert settings.max_depth == 3
    assert settings.max_directories == 1000
    assert settings.max_files == 50000
    assert settings.obey_robots_txt is False
    assert settings.per_host_delay_seconds == 1.5
    assert settings.fetch_file_size is False
    assert seeds == ("https://mirror.example.org/pub/",)


def test_build_settings_defaults() -> None:
    args = argparse.Namespace(
        seed_urls=[],
        host=None,
        port=None,
        db=None,
        max_concurrent_requests=None,
        max_depth=None,
        max_directories=None,
        max_files=None,
        no_robots=False,
        per_host_delay=None,
        no_file_size=False,
    )
    settings, seeds = build_settings(args)

    assert settings.host == "127.0.0.1"
    assert settings.port == 8000
    assert settings.obey_robots_txt is True
    assert settings.per_host_delay_seconds == 0.5
    assert settings.fetch_file_size is True
    assert seeds == ()
