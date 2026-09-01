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


def posix(path: str) -> str:
    return path.replace("\\", "/").lstrip("/")


def object_container(normalized: str) -> str | None:
    parts = list(PurePosixPath(normalized).parts)
    if "objects" not in parts:
        return None
    index = parts.index("objects")
    if index + 1 >= len(parts):
        return None
    return str(PurePosixPath(*parts[: index + 2]))


def object_meta_path(normalized: str) -> str | None:
    container = object_container(normalized)
    if container is None:
        return None
    object_name = PurePosixPath(container).name
    return f"{container}/{object_name}.object-meta.xml"


def copy_from_source_root(source_root: Path, root: Path, normalized: str) -> bool:
    parts = PurePosixPath(normalized).parts
    source = source_root.joinpath(*parts)
    if not source.exists():
        return False
    dest = root.joinpath(*parts)
    if source.is_dir():
        shutil.copytree(source, dest, dirs_exist_ok=True)
    else:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, dest)
    return dest.exists()


def checkout_from_ref(source_ref: str, root: Path, normalized: str) -> bool:
    completed = subprocess.run(
        ["git", "checkout", source_ref, "--", normalized],
        cwd=root,
        capture_output=True,
        text=True,
    )
    return completed.returncode == 0 and root.joinpath(*PurePosixPath(normalized).parts).exists()


def materialize(normalized: str, root: Path, source_root: Path | None, source_ref: str | None) -> Path:
    local = root.joinpath(*PurePosixPath(normalized).parts)
    if local.exists():
        return local
    if source_root is not None and copy_from_source_root(source_root, root, normalized):
        return local
    if source_ref and checkout_from_ref(source_ref, root, normalized):
        return local
    raise ValueError(
        f"Metadata path does not exist on the checked-out branch: {normalized}"
    )


def add_companion_files(normalized: str, local: Path, root: Path, selected: list[str]) -> None:
    if local.is_file() and not normalized.endswith("-meta.xml"):
        companion = root / (normalized + "-meta.xml")
        if companion.exists():
            selected.append(normalized + "-meta.xml")


def ensure_object_structure(
    normalized: str,
    root: Path,
    source_root: Path | None,
    source_ref: str | None,
    selected: list[str],
) -> None:
    meta = object_meta_path(normalized)
    if meta is None:
        return
    try:
        materialize(meta, root, source_root, source_ref)
    except ValueError:
        # Standard objects often have fields without a CustomObject file.
        return
    if meta not in selected:
        selected.append(meta)


def safe_paths(
    raw: object,
    root: Path,
    source_root: Path | None = None,
    source_ref: str | None = None,
) -> list[str]:
    if not isinstance(raw, list) or not raw:
        raise ValueError("Component paths must be a non-empty JSON array.")
    selected: list[str] = []
    for item in raw:
        if not isinstance(item, str):
            raise ValueError("Every component path must be text.")
        normalized = posix(item)
        parts = PurePosixPath(normalized).parts
        if not normalized.startswith("force-app/") or ".." in parts:
            raise ValueError(f"Unsafe metadata path: {item}")
        local = materialize(normalized, root, source_root, source_ref)
        selected.append(normalized)
        add_companion_files(normalized, local, root, selected)
        ensure_object_structure(normalized, root, source_root, source_ref, selected)
    return list(dict.fromkeys(selected))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", required=True, choices=("validate", "deploy"))
    parser.add_argument("--paths-file", required=True)
    parser.add_argument("--target-org", default="target-org")
    parser.add_argument("--test-level", default="NoTestRun")
    parser.add_argument("--output", required=True)
    parser.add_argument(
        "--source-root",
        default=os.environ.get("OAUTH_DEPLOY_SOURCE_ROOT"),
        help="Local checkout of the default branch used to fill missing folders or files.",
    )
    parser.add_argument(
        "--source-ref",
        default=os.environ.get("OAUTH_DEPLOY_SOURCE_REF"),
        help="Git ref of the default branch used to fill missing folders or files.",
    )
    args = parser.parse_args()

    root = Path.cwd().resolve()
    source_root = Path(args.source_root).resolve() if args.source_root else None
    try:
        raw = json.loads(Path(args.paths_file).read_text(encoding="utf-8"))
        paths = safe_paths(raw, root, source_root=source_root, source_ref=args.source_ref)
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
