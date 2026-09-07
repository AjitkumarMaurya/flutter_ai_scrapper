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
