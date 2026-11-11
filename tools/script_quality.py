#!/usr/bin/env python3
"""Fail-closed static Luau syntax/bytecode checks across all Roblox games.

A successful compilation is not proof of correct Roblox APIs or runtime.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def list_sources(root: Path) -> list[Path]:
    paths: set[Path] = set()
    for base in (root / "games" / "maps", root / "packages"):
        if not base.is_dir():
            raise ValueError(f"Missing source directory: {base}")
        for pattern in ("*.luau", "*.lua"):
            paths.update(p for p in base.rglob(pattern) if p.is_file())
    if not paths:
        raise ValueError("No Luau source files found")
    return sorted(paths)


def check_sources(sources: list[Path], compiler: str, root: Path) -> tuple[int, int]:
    passed = 0
    failed = 0
    for path in sources:
        label = path.relative_to(root).as_posix()
        try:
            proc = subprocess.run(
                [compiler, "--null", str(path)], capture_output=True,
                text=True, timeout=20, check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            print(f"::error file={label}::Luau compiler unavailable: {exc}", file=sys.stderr)
            failed += 1
            continue
        if proc.returncode == 0:
            passed += 1
            print(f"PASS {label}", flush=True)
        else:
            failed += 1
            print(f"FAIL {label} (exit {proc.returncode})", file=sys.stderr)
            print((proc.stderr + "\n" + proc.stdout).strip(), file=sys.stderr)
            print(f"::error file={label}::Luau syntax/bytecode compilation failed", file=sys.stderr)
    return passed, failed


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--compiler", default=os.environ.get("LUAU_COMPILER", "luau-compile"))
    args = parser.parse_args(argv)
    compiler = shutil.which(args.compiler)
    if not compiler:
        print("ERROR: luau-compile is missing; install official Luau", file=sys.stderr)
        return 2
    root = args.root.resolve()
    try:
        sources = list_sources(root)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    passed, failed = check_sources(sources, compiler, root)
    print(f"LUAU SUMMARY: {passed} passed; {failed} failed; {len(sources)} files")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
