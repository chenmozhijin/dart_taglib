#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT

"""Check SPDX boundaries for source, configuration, generated assets, and docs."""

from __future__ import annotations

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COPYRIGHT = "SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>"
LICENSE_ID = "SPDX-License-Identifier: MIT"
LINE_COMMENT_SUFFIXES = {
    ".c",
    ".cc",
    ".cpp",
    ".dart",
    ".h",
    ".hpp",
    ".js",
}
HASH_COMMENT_SUFFIXES = {".cmake", ".ps1", ".py", ".yaml", ".yml"}
HASH_COMMENT_NAMES = {".gitignore", ".pubignore", "CMakeLists.txt"}


def _candidate_files() -> list[str]:
    output = subprocess.check_output(
        [
            "git",
            "ls-files",
            "--cached",
            "--others",
            "--exclude-standard",
            "-z",
        ],
        cwd=ROOT,
    )
    return [
        value.decode("utf-8")
        for value in output.split(b"\0")
        if value and not value.decode("utf-8").startswith("third_party/")
    ]


def _expected_header(path: str) -> tuple[str, str] | None:
    file_path = Path(path)
    if file_path.suffix.lower() in LINE_COMMENT_SUFFIXES:
        return f"// {COPYRIGHT}", f"// {LICENSE_ID}"
    if (
        file_path.suffix.lower() in HASH_COMMENT_SUFFIXES
        or file_path.name in HASH_COMMENT_NAMES
    ):
        return f"# {COPYRIGHT}", f"# {LICENSE_ID}"
    if file_path.suffix.lower() == ".html":
        return f"<!-- {COPYRIGHT} -->", f"<!-- {LICENSE_ID} -->"
    return None


def _check_header(path: str, lines: list[str]) -> str | None:
    expected = _expected_header(path)
    if expected is None:
        return None
    start = 1 if lines and lines[0].startswith("#!") else 0
    if tuple(lines[start : start + 2]) != expected:
        return f"{path}: missing or invalid MIT SPDX header"
    return None


def main() -> int:
    errors: list[str] = []
    checked = 0
    for path in _candidate_files():
        absolute = ROOT / path
        if not absolute.is_file():
            continue
        expected = _expected_header(path)
        if expected is not None:
            checked += 1
            lines = absolute.read_text(encoding="utf-8").splitlines()
            error = _check_header(path, lines)
            if error is not None:
                errors.append(error)
            continue

        if path.endswith((".json", ".md")) or Path(path).name in {
            "LICENSE",
            "THIRD_PARTY_NOTICES.md",
        }:
            text = absolute.read_text(encoding="utf-8")
            if "SPDX-FileCopyrightText:" in text:
                errors.append(f"{path}: JSON, licenses, and user docs must not embed SPDX headers")

    if errors:
        print("\n".join(errors))
        return 1
    print(f"License header check passed: project={checked}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
