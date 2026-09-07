from __future__ import annotations

import pytest

from database import _build_fts_query, _escape_like
from utils import (
    FILE_TYPE_ARCHIVE,
    FILE_TYPE_AUDIO,
    FILE_TYPE_DOCUMENT,
    FILE_TYPE_EXECUTABLE,
    FILE_TYPE_OTHER,
    FILE_TYPE_VIDEO,
    canonical_directory_url,
    canonicalize_seed_url,
    get_file_name,
    get_file_type,
    is_directory_url,
    is_excluded_asset,
    is_within_directory,
    normalize_type,
    normalize_url,
    should_index_file,
    split_extension,
)


class TestExtensionMapping:
    def test_compound_extensions(self) -> None:
        assert split_extension("archive.tar.gz") == ".tar.gz"
        assert split_extension("backup.TAR.BZ2") == ".tar.bz2"
        assert split_extension("file.tar.xz") == ".tar.xz"
        assert split_extension("data.tar.zst") == ".tar.zst"

    def test_single_extensions(self) -> None:
        assert split_extension("video.mp4") == ".mp4"
        assert split_extension("audio.MP3") == ".mp3"
        assert split_extension("document.pdf") == ".pdf"
        assert split_extension("archive.zip") == ".zip"
        assert split_extension("installer.exe") == ".exe"

    def test_no_extension_or_hidden(self) -> None:
        assert split_extension("README") == ""
        assert split_extension(".bashrc") == ""
        assert split_extension("test.") == ""
        assert split_extension("") == ""

    def test_get_file_type_categories(self) -> None:
        assert get_file_type("movie.mkv") == FILE_TYPE_VIDEO
        assert get_file_type("song.flac") == FILE_TYPE_AUDIO
        assert get_file_type("paper.epub") == FILE_TYPE_DOCUMENT
        assert get_file_type("bundle.7z") == FILE_TYPE_ARCHIVE
        assert get_file_type("setup.msi") == FILE_TYPE_EXECUTABLE
        assert get_file_type("notes.unknown_ext") == FILE_TYPE_OTHER


class TestURLUtilities:
    def test_normalize_url_basic_and_relative(self) -> None:
        base = "https://example.com/files/"
        assert normalize_url(base, "movie.mp4") == "https://example.com/files/movie.mp4"
        assert normalize_url(base, "sub/") == "https://example.com/files/sub/"
        assert normalize_url(base, "../other/doc.pdf") == "https://example.com/other/doc.pdf"

    def test_normalize_url_disallowed_schemes_and_fragments(self) -> None:
        base = "https://example.com/"
        assert normalize_url(base, "mailto:test@example.com") is None
        assert normalize_url(base, "javascript:alert(1)") is None
        assert normalize_url(base, "tel:+1234567890") is None
        assert normalize_url(base, "#anchor") is None
        assert normalize_url(base, "") is None

    def test_normalize_url_strips_fragments(self) -> None:
        base = "https://example.com/index/"
        normalized = normalize_url(base, "file.iso#section")
        assert normalized == "https://example.com/index/file.iso"

    def test_canonicalize_seed_url(self) -> None:
        assert canonicalize_seed_url("https://example.com/pub") == "https://example.com/pub/"
        assert canonicalize_seed_url("https://example.com/pub/") == "https://example.com/pub/"
        assert canonicalize_seed_url("ftp://example.com/pub") is None
        assert canonicalize_seed_url("not a url") is None

    def test_canonical_directory_url(self) -> None:
        assert canonical_directory_url("https://example.com/dir") == "https://example.com/dir/"
        assert canonical_directory_url("https://example.com/dir/") == "https://example.com/dir/"

    def test_is_directory_url(self) -> None:
        assert is_directory_url("https://example.com/dir/") is True
        assert is_directory_url("https://example.com/dir/file.txt") is False

    def test_is_within_directory(self) -> None:
        root = "https://example.com/files/"
        assert is_within_directory(root, "https://example.com/files/sub/") is True
        assert is_within_directory(root, "https://example.com/files/sub/deep/") is True
        assert is_within_directory(root, "https://example.com/other/") is False
        assert is_within_directory(root, "https://different.org/files/") is False


class TestAssetExclusionAndIndexing:
    def test_is_excluded_asset(self) -> None:
        assert is_excluded_asset("https://example.com/style.css") is True
        assert is_excluded_asset("https://example.com/app.js") is True
        assert is_excluded_asset("https://example.com/logo.svg") is True
        assert is_excluded_asset("https://example.com/page.html") is True
        assert is_excluded_asset("https://example.com/photo.png") is True
        assert is_excluded_asset("https://example.com/Thumbs.db") is True
        assert is_excluded_asset("https://example.com/.DS_Store") is True
        assert is_excluded_asset("https://example.com/video.mp4") is False

    def test_should_index_file(self) -> None:
        assert should_index_file("https://example.com/files/video.mp4") is True
        assert should_index_file("https://example.com/files/") is False
        assert should_index_file("https://example.com/files/page.html") is False
        assert should_index_file("https://example.com/") is False


class TestTypeAliases:
    def test_normalize_type_aliases(self) -> None:
        assert normalize_type("video") == FILE_TYPE_VIDEO
        assert normalize_type("VIDEOS") == FILE_TYPE_VIDEO
        assert normalize_type("music") == FILE_TYPE_AUDIO
        assert normalize_type("sound") == FILE_TYPE_AUDIO
        assert normalize_type("docs") == FILE_TYPE_DOCUMENT
        assert normalize_type("ebook") == FILE_TYPE_DOCUMENT
        assert normalize_type("archives") == FILE_TYPE_ARCHIVE
        assert normalize_type("app") == FILE_TYPE_EXECUTABLE
        assert normalize_type("software") == FILE_TYPE_EXECUTABLE
        assert normalize_type("nonexistent") is None
        assert normalize_type(None) is None


class TestDatabaseHelperQueries:
    def test_escape_like(self) -> None:
        assert _escape_like("100%_pure\\test") == "100\\%\\_pure\\\\test"

    def test_build_fts_query(self) -> None:
        assert _build_fts_query("ubuntu 24.04") == '"ubuntu"* "24.04"*'
        assert _build_fts_query('test "special"') == '"test"* "special"*'
        assert _build_fts_query("   ") == ""
