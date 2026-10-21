#!/usr/bin/env python3
"""Stamp VERSION into src/version.rs and flutter/pubspec.yaml.

cargo's build.rs rewrites version.rs from SC_RELEASE_TAG, VERSION,
GITHUB_REF_NAME, or the pubspec version. The Linux release job compiles
inside a container that used to see none of those, so the binary kept the
pubspec tag. Writing both files on the host, before that container starts,
keeps About and the update rank on the release tag.

The +build already in pubspec is kept. Set BUILD_NUMBER to replace it.
When RELEASE_NOTES is set, it replaces release-notes.txt (\\n becomes a
newline) so the GitHub release body matches this run.
"""

import os
import pathlib
import sys


def main() -> None:
    ver = os.environ.get("VERSION", "").strip()
    if not ver or "-sc" not in ver:
        sys.exit(f"VERSION must look like 1.4.9-scN, got {ver!r}")

    root = pathlib.Path(__file__).resolve().parents[1]
    stamp_version_rs(root / "src" / "version.rs", ver)
    build = stamp_pubspec(root / "flutter" / "pubspec.yaml", ver)
    notes = os.environ.get("RELEASE_NOTES", "").strip()
    if notes:
        if "\\n" in notes and "\n" not in notes:
            notes = notes.replace("\\n", "\n")
        (root / "release-notes.txt").write_text(notes.rstrip() + "\n", encoding="utf-8")
    print(f"stamped {ver}+{build}")


def stamp_version_rs(path: pathlib.Path, ver: str) -> None:
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    out = []
    saw_version = False
    saw_release = False
    for line in text.splitlines():
        if line.startswith("pub const VERSION:"):
            out.append(f'pub const VERSION: &str = "{ver}";')
            saw_version = True
        elif line.startswith("pub const RELEASE_TAG:"):
            out.append(f'pub const RELEASE_TAG: &str = "{ver}";')
            saw_release = True
        else:
            out.append(line)
    if not saw_version:
        out.insert(0, f'pub const VERSION: &str = "{ver}";')
    if not saw_release:
        out.append(f'pub const RELEASE_TAG: &str = "{ver}";')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(out) + "\n", encoding="utf-8")


def stamp_pubspec(path: pathlib.Path, ver: str) -> str:
    build = os.environ.get("BUILD_NUMBER", "").strip() or "2089"
    lines = path.read_text(encoding="utf-8").splitlines()
    out = []
    saw = False
    for line in lines:
        if line.startswith("version:"):
            rest = line.split(":", 1)[1].strip()
            if not os.environ.get("BUILD_NUMBER", "").strip() and "+" in rest:
                suffix = rest.split("+", 1)[1].strip()
                if suffix:
                    build = suffix
            out.append(f"version: {ver}+{build}")
            saw = True
        else:
            out.append(line)
    if not saw:
        sys.exit(f"{path} has no version: line")
    path.write_text("\n".join(out) + "\n", encoding="utf-8")
    return build


if __name__ == "__main__":
    main()
