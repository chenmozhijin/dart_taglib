#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT

"""Stage the tracked files that are eligible for the Pub package archive."""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PUBIGNORE = ROOT / ".pubignore"
PUB_METADATA = {".gitignore", ".gitmodules", ".pubignore"}


def _run(args: list[str], cwd: Path, *, input_bytes: bytes | None = None) -> bytes:
    result = subprocess.run(
        args,
        cwd=cwd,
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    return result.stdout


def _tracked_files(repository: Path) -> tuple[list[str], list[str]]:
    records = _run(
        ["git", "ls-files", "--cached", "--stage", "-z"],
        repository,
    ).split(b"\0")
    files: list[str] = []
    submodules: list[str] = []
    for record in records:
        if not record:
            continue
        metadata, encoded_path = record.split(b"\t", 1)
        mode = metadata.split(b" ", 1)[0]
        path = encoded_path.decode("utf-8")
        if mode == b"160000":
            submodules.append(path)
        else:
            files.append(path)
    return files, submodules


def _recursive_tracked_files() -> list[str]:
    files: list[str] = []
    pending = [(ROOT, "")]
    while pending:
        repository, prefix = pending.pop()
        local_files, local_submodules = _tracked_files(repository)
        files.extend(f"{prefix}{path}" for path in local_files)
        for submodule in local_submodules:
            child = repository / submodule
            child_prefix = f"{prefix}{submodule}/"
            pending.append((child, child_prefix))
    return files


def _ignored_paths(paths: list[str]) -> set[str]:
    payload = b"\0".join(path.encode("utf-8") for path in paths) + b"\0"
    result = subprocess.run(
        [
            "git",
            "-c",
            f"core.excludesFile={PUBIGNORE}",
            "check-ignore",
            "--no-index",
            "--stdin",
            "-z",
        ],
        cwd=ROOT,
        input=payload,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    return {
        path.decode("utf-8")
        for path in result.stdout.split(b"\0")
        if path
    }


def _stage(output: Path) -> int:
    output = output.resolve()
    archive_root = (ROOT / ".dart_tool" / "pub_archive").resolve()
    if archive_root not in output.parents:
        raise SystemExit(f"Output must be below {archive_root}: {output}")
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)

    tracked = sorted(set(_recursive_tracked_files()))
    ignored = _ignored_paths(tracked)
    included = [
        path
        for path in tracked
        if path not in ignored and Path(path).name not in PUB_METADATA
    ]
    for relative in included:
        source = ROOT / relative
        target = output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)

    required = [
        "pubspec.yaml",
        "lib/dart_taglib.dart",
        "hook/build.dart",
        "native/taglib_bridge/CMakeLists.txt",
        "web_runtime/manifest.json",
        "third_party/taglib/CMakeLists.txt",
        "third_party/taglib/3rdparty/utfcpp/CMakeLists.txt",
    ]
    missing = [path for path in required if not (output / path).is_file()]
    if missing:
        raise SystemExit(f"Staged package is missing required files: {missing}")
    forbidden_prefixes = (".github", "test", "tool", "wasm")
    forbidden = [
        path
        for path in included
        if Path(path).parts and Path(path).parts[0] in forbidden_prefixes
    ]
    if forbidden:
        raise SystemExit(f"Staged package contains forbidden paths: {forbidden}")
    print(f"Staged {len(included)} files at {output}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    return _stage(args.output)


if __name__ == "__main__":
    raise SystemExit(main())
