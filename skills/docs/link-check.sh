#!/usr/bin/env python3
"""
link-check.sh — Markdown local link validator.

Usage:
    link-check.sh [directory]

Walks all *.md files under [directory] (default: current working directory),
extracts inline links, image links, and reference definitions, and checks
that local targets exist on disk. Skips HTTP/HTTPS/mailto/ftp/tel URLs,
pure anchors (#...), and empty targets.

Output: one line per broken link on stdout:
    <source.md>:<lineno>: broken link: <target>

Summary on stderr:
    N broken links in M files (scanned K files)

Exit code: 0 if clean, 1 if any broken links found.
"""

import os
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

SKIP_DIRS = {
    "node_modules", "vendor", "third_party", ".git",
    "build", "dist", ".venv", "venv", "__pycache__",
}

SKIP_SCHEMES = {"http", "https", "mailto", "ftp", "tel"}

# Matches: ![alt](target), [text](target)
INLINE_RE = re.compile(r'!?\[(?:[^\[\]]*(?:\[[^\[\]]*\])?[^\[\]]*)\]\(([^)]*)\)')

# Matches reference definitions at column 0: [label]: target
REF_DEF_RE = re.compile(r'^\[(?:[^\[\]]+)\]:\s+(\S+)')


def is_skip_target(target: str) -> bool:
    """Return True if we should skip this link target."""
    if not target:
        return True
    if target.startswith("#"):
        return True
    parsed = urlparse(target)
    if parsed.scheme in SKIP_SCHEMES:
        return True
    return False


def strip_fragment_and_query(target: str) -> str:
    """Remove #fragment and ?query from a local path."""
    # Strip fragment
    if "#" in target:
        target = target[:target.index("#")]
    # Strip query
    if "?" in target:
        target = target[:target.index("?")]
    return target


def check_file(md_path: Path, root: Path) -> list[tuple[int, str]]:
    """Return list of (lineno, target) for broken links in md_path."""
    broken = []
    try:
        with md_path.open(encoding="utf-8", errors="replace") as f:
            for lineno, line in enumerate(f, start=1):
                targets = []
                try:
                    for m in INLINE_RE.finditer(line):
                        targets.append(m.group(1).strip())
                    if REF_DEF_RE.match(line):
                        m = REF_DEF_RE.match(line)
                        targets.append(m.group(1).strip())
                except Exception:
                    continue  # skip malformed lines

                for raw_target in targets:
                    if is_skip_target(raw_target):
                        continue
                    target = strip_fragment_and_query(raw_target)
                    if not target:
                        continue

                    # Resolve relative to the source file's directory
                    source_dir = md_path.parent
                    resolved = (source_dir / target).resolve()

                    # Security: don't follow symlinks outside root
                    try:
                        resolved.relative_to(root.resolve())
                    except ValueError:
                        # Outside root — treat as broken (or skip?)
                        broken.append((lineno, raw_target))
                        continue

                    if not resolved.exists():
                        broken.append((lineno, raw_target))

    except OSError:
        pass  # unreadable file — skip silently
    return broken


def walk_md_files(root: Path):
    """Yield Path objects for all *.md files under root, skipping SKIP_DIRS."""
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        # Prune skip dirs in-place
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if name.endswith(".md"):
                yield Path(dirpath) / name


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    root = root.resolve()

    if not root.is_dir():
        print(f"error: {root} is not a directory", file=sys.stderr)
        sys.exit(2)

    total_files = 0
    files_with_breaks = 0
    total_broken = 0

    for md_path in sorted(walk_md_files(root)):
        total_files += 1
        broken = check_file(md_path, root)
        if broken:
            files_with_breaks += 1
            for lineno, target in broken:
                total_broken += 1
                rel = md_path.relative_to(root)
                print(f"{rel}:{lineno}: broken link: {target}")

    print(
        f"{total_broken} broken link{'s' if total_broken != 1 else ''} "
        f"in {files_with_breaks} file{'s' if files_with_breaks != 1 else ''} "
        f"(scanned {total_files} file{'s' if total_files != 1 else ''})",
        file=sys.stderr,
    )

    sys.exit(1 if total_broken > 0 else 0)


if __name__ == "__main__":
    main()
