#!/usr/bin/env python3
"""Fail the workflow when AI changes blocked paths or exceeds change limits."""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from discover_components import is_allowed_path, is_blocked_path

ROOT = Path(__file__).resolve().parents[1]


def git_name_only(base: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", base],
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip().replace("\\", "/") for line in result.stdout.splitlines() if line.strip()]


def git_diff_stat(base: str) -> int:
    result = subprocess.run(
        ["git", "diff", "--numstat", base],
        check=True,
        capture_output=True,
        text=True,
    )
    total = 0
    for line in result.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) >= 2 and parts[0].isdigit() and parts[1].isdigit():
            total += int(parts[0]) + int(parts[1])
    return total


def load_policy() -> dict:
    return json.loads((ROOT / "ai" / "workspace-policy.json").read_text(encoding="utf-8"))


def restore(paths: list[str]) -> None:
    if not paths:
        return
    subprocess.run(["git", "checkout", "--", *paths], check=False)


def missing_apex_tests(paths: list[str]) -> bool:
    production_apex = any(
        path.lower().endswith(".trigger")
        or (
            path.lower().endswith(".cls")
            and not Path(path).name.lower().endswith("test.cls")
        )
        for path in paths
    )
    changed_tests = any(
        path.lower().endswith("test.cls")
        for path in paths
    )
    return production_apex and not changed_tests


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="HEAD")
    parser.add_argument("--max-files", type=int)
    parser.add_argument("--max-diff-lines", type=int)
    args = parser.parse_args()
    policy = load_policy()
    changed = git_name_only(args.base)
    blocked = [
        path
        for path in changed
        if is_blocked_path(path, policy) or not is_allowed_path(path, policy)
    ]
    if blocked:
        restore(blocked)
        print("Blocked path modifications detected:", file=sys.stderr)
        print("\n".join(blocked), file=sys.stderr)
        return 2
    max_files = args.max_files or int(policy.get("max_changed_files", 20))
    max_lines = args.max_diff_lines or int(policy.get("max_diff_lines", 2000))
    if len(changed) > max_files:
        print(f"Changed file count {len(changed)} exceeds limit {max_files}.", file=sys.stderr)
        return 3
    diff_lines = git_diff_stat(args.base)
    if diff_lines > max_lines:
        print(f"Diff line count {diff_lines} exceeds limit {max_lines}.", file=sys.stderr)
        return 3
    if missing_apex_tests(changed):
        print(
            "Apex production changes require an accompanying changed Apex test class.",
            file=sys.stderr,
        )
        return 4
    print(json.dumps({"changed": changed, "diffLines": diff_lines}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
