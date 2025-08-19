#!/usr/bin/env python3
import argparse
import os
import re
import sqlite3
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from html.parser import HTMLParser
from pathlib import Path
from typing import Iterable, List, Optional, Tuple


DEFAULT_EXCLUDED_DIRS = {
    ".git",
    "node_modules",
    "__pycache__",
    ".venv",
    "venv",
    ".mypy_cache",
    ".pytest_cache",
}

TEXT_LIKE_EXTENSIONS = {
    ".txt",
    ".md",
    ".markdown",
    ".rst",
    ".py",
    ".js",
    ".ts",
    ".tsx",
    ".jsx",
    ".json",
    ".yml",
    ".yaml",
    ".toml",
    ".ini",
    ".cfg",
    ".env",
    ".log",
    ".html",
    ".htm",
    ".css",
    ".sql",
    ".csv",
    ".tsv",
}


class SimpleHTMLTextExtractor(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self._chunks: List[str] = []

    def handle_data(self, data: str) -> None:
        if data:
            self._chunks.append(data)

    def handle_entityref(self, name: str) -> None:
        self._chunks.append(f"&{name};")

    def get_text(self) -> str:
        return " ".join(chunk.strip() for chunk in self._chunks if chunk.strip())


def strip_html_to_text(html_content: str) -> str:
    parser = SimpleHTMLTextExtractor()
    try:
        parser.feed(html_content)
        parser.close()
    except Exception:
        # As a fallback, remove tags via regex if parser fails
        return re.sub(r"<[^>]+>", " ", html_content)
    return parser.get_text()


def looks_binary(sample: bytes) -> bool:
    if b"\x00" in sample:
        return True
    # Heuristic: if too many non-text bytes, consider binary
    text_chars = bytearray({7, 8, 9, 10, 12, 13, 27} | set(range(0x20, 0x100)))
    nontext = sample.translate(None, text_chars)
    return float(len(nontext)) / float(max(1, len(sample))) > 0.30


def read_file_text(path: Path, size_threshold_bytes: int = 15 * 1024 * 1024) -> Optional[str]:
    try:
        stat = path.stat()
        if stat.st_size == 0:
            return ""
        if stat.st_size > size_threshold_bytes:
            return None
        with path.open("rb") as f:
            sample = f.read(4096)
            if looks_binary(sample):
                return None
            rest = f.read()
            content_bytes = sample + rest
        try:
            text = content_bytes.decode("utf-8")
        except UnicodeDecodeError:
            try:
                text = content_bytes.decode("latin-1")
            except Exception:
                return None
        if path.suffix.lower() in {".html", ".htm"}:
            return strip_html_to_text(text)
        return text
    except Exception:
        return None


@dataclass
class FileRecord:
    path: str
    filename: str
    extension: str
    directory: str
    mtime: float
    size: int
    content: Optional[str]


def iter_files(root: Path, exclude_dirs: Iterable[str]) -> Iterable[Path]:
    excluded_set = set(exclude_dirs)
    for dirpath, dirnames, filenames in os.walk(root):
        # Prune excluded directories in-place
        dirnames[:] = [d for d in dirnames if d not in excluded_set]
        for name in filenames:
            yield Path(dirpath) / name


def gather_records(root: Path, exclude_dirs: Iterable[str]) -> Iterable[FileRecord]:
    for path in iter_files(root, exclude_dirs):
        try:
            stat = path.stat()
            content = read_file_text(path)
            yield FileRecord(
                path=str(path.resolve()),
                filename=path.name,
                extension=path.suffix.lower(),
                directory=str(path.parent.resolve()),
                mtime=stat.st_mtime,
                size=stat.st_size,
                content=content,
            )
        except FileNotFoundError:
            continue


def init_db(conn: sqlite3.Connection) -> Tuple[str, str]:
    cur = conn.cursor()
    cur.execute("PRAGMA journal_mode=WAL;")
    cur.execute("PRAGMA synchronous=NORMAL;")
    cur.execute("PRAGMA temp_store=MEMORY;")

    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS files (
            path TEXT PRIMARY KEY,
            filename TEXT NOT NULL,
            extension TEXT NOT NULL,
            directory TEXT NOT NULL,
            mtime REAL NOT NULL,
            size INTEGER NOT NULL
        );
        """
    )

    # Try FTS5, then FTS4, otherwise fallback to plain table
    fts_table = "docs"
    fts_version = "none"
    try:
        cur.execute("DROP TABLE IF EXISTS docs;")
        cur.execute("CREATE VIRTUAL TABLE docs USING fts5(path, content, tokenize='porter');")
        fts_version = "fts5"
    except sqlite3.OperationalError:
        try:
            cur.execute("DROP TABLE IF EXISTS docs;")
            cur.execute("CREATE VIRTUAL TABLE docs USING fts4(path, content);")
            fts_version = "fts4"
        except sqlite3.OperationalError:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS docs_plain (
                    path TEXT PRIMARY KEY,
                    content TEXT
                );
                """
            )
            fts_table = "docs_plain"
            fts_version = "plain"

    # Simple index for metadata
    cur.execute("CREATE INDEX IF NOT EXISTS idx_files_dir ON files(directory);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_files_ext ON files(extension);")
    conn.commit()
    return fts_version, fts_table


def rebuild_index(db_path: Path, root: Path, exclude_dirs: Iterable[str]) -> Tuple[str, str]:
    if db_path.exists():
        db_path.unlink()
    conn = sqlite3.connect(str(db_path))
    try:
        fts_version, fts_table = init_db(conn)
        cur = conn.cursor()

        # Clear any existing rows (fresh DB, but keep idempotent)
        cur.execute("DELETE FROM files;")
        if fts_version in {"fts5", "fts4"}:
            cur.execute(f"DELETE FROM {fts_table};")
        else:
            cur.execute("DELETE FROM docs_plain;")
        conn.commit()

        batch_meta: List[Tuple] = []
        batch_docs: List[Tuple] = []
        batch_size = 200
        total = 0
        indexed = 0

        for rec in gather_records(root, exclude_dirs):
            total += 1
            batch_meta.append((rec.path, rec.filename, rec.extension, rec.directory, rec.mtime, rec.size))
            if rec.content is not None:
                batch_docs.append((rec.path, rec.content))
                indexed += 1

            if len(batch_meta) >= batch_size:
                cur.executemany(
                    "INSERT OR REPLACE INTO files(path, filename, extension, directory, mtime, size) VALUES (?, ?, ?, ?, ?, ?);",
                    batch_meta,
                )
                batch_meta.clear()
            if len(batch_docs) >= batch_size:
                if fts_version in {"fts5", "fts4"}:
                    cur.executemany(
                        f"INSERT INTO {fts_table}(path, content) VALUES (?, ?);",
                        batch_docs,
                    )
                else:
                    cur.executemany(
                        "INSERT OR REPLACE INTO docs_plain(path, content) VALUES (?, ?);",
                        batch_docs,
                    )
                batch_docs.clear()

        # Flush remaining
        if batch_meta:
            cur.executemany(
                "INSERT OR REPLACE INTO files(path, filename, extension, directory, mtime, size) VALUES (?, ?, ?, ?, ?, ?);",
                batch_meta,
            )
        if batch_docs:
            if fts_version in {"fts5", "fts4"}:
                cur.executemany(
                    f"INSERT INTO {fts_table}(path, content) VALUES (?, ?);",
                    batch_docs,
                )
            else:
                cur.executemany(
                    "INSERT OR REPLACE INTO docs_plain(path, content) VALUES (?, ?);",
                    batch_docs,
                )
        conn.commit()
        print(f"Indexed {indexed} text-like files out of {total} total files. FTS mode: {fts_version}.")
        return fts_version, fts_table
    finally:
        conn.close()


def search(db_path: Path, query: str, limit: int = 10) -> List[Tuple[str, str]]:
    conn = sqlite3.connect(str(db_path))
    try:
        cur = conn.cursor()
        # Determine available search mode
        has_docs = cur.execute(
            "SELECT name FROM sqlite_master WHERE type in ('table', 'view') AND name IN ('docs', 'docs_plain');"
        ).fetchall()
        if not has_docs:
            raise RuntimeError("Index not found. Run the 'index' command first.")

        if any(name for (name,) in has_docs if name == "docs"):
            try:
                rows = cur.execute(
                    "SELECT path, snippet(docs, 1, '[', ']', '…', 10) FROM docs WHERE docs MATCH ? LIMIT ?;",
                    (query, limit),
                ).fetchall()
                return rows
            except sqlite3.OperationalError:
                # FTS4 may not support snippet with same signature; fallback to simple select
                rows = cur.execute(
                    "SELECT path, substr(content, 1, 200) FROM docs WHERE docs MATCH ? LIMIT ?;",
                    (query, limit),
                ).fetchall()
                return rows
        else:
            # Plain LIKE fallback
            like = f"%{query.replace('%', '')}%"
            rows = cur.execute(
                "SELECT path, substr(content, 1, 200) FROM docs_plain WHERE content LIKE ? LIMIT ?;",
                (like, limit),
            ).fetchall()
            return rows
    finally:
        conn.close()


def human_time(ts: float) -> str:
    try:
        return datetime.fromtimestamp(ts).isoformat(timespec="seconds")
    except Exception:
        return str(ts)


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Scan a repository and build a SQLite full-text index.")
    subparsers = parser.add_subparsers(dest="cmd", required=True)

    p_index = subparsers.add_parser("index", help="Build or rebuild the index")
    p_index.add_argument("--root", type=Path, required=True, help="Root directory to scan")
    p_index.add_argument("--db", type=Path, required=True, help="Path to SQLite index file")
    p_index.add_argument(
        "--exclude",
        action="append",
        default=[],
        help="Directory name to exclude (can be repeated). Default excludes common build and VCS dirs.",
    )

    p_search = subparsers.add_parser("search", help="Query the index")
    p_search.add_argument("--db", type=Path, required=True, help="Path to SQLite index file")
    p_search.add_argument("--query", required=True, help="FTS query string (or plain substring if no FTS)")
    p_search.add_argument("--limit", type=int, default=10, help="Maximum number of results")

    args = parser.parse_args(argv)

    if args.cmd == "index":
        root: Path = args.root.resolve()
        db_path: Path = args.db.resolve()
        exclude = set(DEFAULT_EXCLUDED_DIRS)
        exclude.update(args.exclude)
        start = time.time()
        fts_version, _ = rebuild_index(db_path=db_path, root=root, exclude_dirs=exclude)
        elapsed = time.time() - start
        print(f"Index built at {db_path} using {fts_version} in {elapsed:.2f}s for root {root}")
        return 0
    elif args.cmd == "search":
        rows = search(db_path=args.db.resolve(), query=args.query, limit=args.limit)
        for path, snippet in rows:
            print(f"- {path}\n  {snippet}\n")
        if not rows:
            print("No results.")
        return 0
    else:
        parser.print_help()
        return 2


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())

