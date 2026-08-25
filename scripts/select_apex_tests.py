#!/usr/bin/env python3
"""Select Apex test classes changed by the AI for Salesforce validation."""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


def changed_paths(base: str) -> list[str]:
    subprocess.run(["git", "add", "-A", "--", "force-app"], check=True)
    result = subprocess.run(
        ["git", "diff", "--cached", "--name-only", base, "--", "force-app"],
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip().replace("\\", "/") for line in result.stdout.splitlines() if line.strip()]


def test_classes(paths: list[str]) -> list[str]:
    names: set[str] = set()
    for path in paths:
        file = Path(path)
        if (
            "/classes/" in path
            and file.name.lower().endswith("test.cls")
            and not file.name.endswith("-meta.xml")
        ):
            names.add(file.name[: -len(".cls")])
    return sorted(names)


def has_apex_production_changes(paths: list[str]) -> bool:
    for path in paths:
        lowered = path.lower()
        if lowered.endswith(".trigger"):
            return True
        if lowered.endswith(".cls") and not Path(lowered).name.endswith("test.cls"):
            return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--out")
    args = parser.parse_args()
    paths = changed_paths(args.base)
    tests = test_classes(paths)
    payload = {
        "tests": tests,
        "hasApexProductionChanges": has_apex_production_changes(paths),
    }
    if payload["hasApexProductionChanges"] and not tests:
        print(
            "Apex production code changed without an accompanying changed test class.",
            flush=True,
        )
        return 2
    text = json.dumps(payload, indent=2)
    if args.out:
        Path(args.out).write_text(text, encoding="utf-8")
    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
