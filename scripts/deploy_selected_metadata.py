#!/usr/bin/env python3
"""Validate and deploy a server-approved list of Salesforce source paths."""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path, PurePosixPath

SF_COMMAND = shutil.which("sf") or shutil.which("sf.cmd") or "sf"


def safe_paths(raw: object, root: Path) -> list[str]:
    if not isinstance(raw, list) or not raw:
        raise ValueError("Component paths must be a non-empty JSON array.")
    selected: list[str] = []
    for item in raw:
        if not isinstance(item, str):
            raise ValueError("Every component path must be text.")
        normalized = item.replace("\\", "/").lstrip("/")
        parts = PurePosixPath(normalized).parts
        if not normalized.startswith("force-app/") or ".." in parts:
            raise ValueError(f"Unsafe metadata path: {item}")
        local = root.joinpath(*parts)
        if not local.exists():
            raise ValueError(f"Metadata path does not exist on the checked-out branch: {normalized}")
        selected.append(normalized)
        if local.is_file() and not normalized.endswith("-meta.xml"):
            companion = root / (normalized + "-meta.xml")
            if companion.exists():
                selected.append(normalized + "-meta.xml")
    return list(dict.fromkeys(selected))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", required=True, choices=("validate", "deploy"))
    parser.add_argument("--paths-file", required=True)
    parser.add_argument("--target-org", default="target-org")
    parser.add_argument("--test-level", default="NoTestRun")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    root = Path.cwd().resolve()
    try:
        raw = json.loads(Path(args.paths_file).read_text(encoding="utf-8"))
        paths = safe_paths(raw, root)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        Path(args.output).write_text(
            json.dumps({"status": 1, "message": str(exc), "result": {}}),
            encoding="utf-8",
        )
        print(str(exc), file=sys.stderr)
        return 1

    command = [SF_COMMAND, "project", "deploy", "start"]
    if args.mode == "validate":
        command.append("--dry-run")
    for path in paths:
        command.extend(["--source-dir", path])
    command.extend([
        "--target-org", args.target_org,
        "--test-level", args.test_level,
        "--wait", "60",
        "--json",
    ])
    result = subprocess.run(command, capture_output=True, text=True, env=os.environ.copy())
    output = result.stdout.strip() or result.stderr.strip()
    try:
        json.loads(output)
    except json.JSONDecodeError:
        output = json.dumps({
            "status": result.returncode or 1,
            "message": "Salesforce CLI did not return valid JSON.",
            "result": {"stderr": result.stderr[-4000:]},
        })
    Path(args.output).write_text(output, encoding="utf-8")
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
