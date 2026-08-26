#!/usr/bin/env python3
"""Print permission metadata required by Apex validation, one path per line."""
from __future__ import annotations

import argparse
import xml.etree.ElementTree as ET
from pathlib import Path


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def custom_permissions(permission_set: Path) -> set[str]:
    root = ET.parse(permission_set).getroot()
    names: set[str] = set()
    for grant in root.iter():
        if local_name(grant.tag) != "customPermissions":
            continue
        for child in grant:
            if local_name(child.tag) == "name" and child.text:
                names.add(child.text.strip())
    return names


def dependencies(source_root: Path) -> list[Path]:
    default_root = source_root / "main" / "default"
    custom_root = default_root / "customPermissions"
    permission_root = default_root / "permissionsets"
    available = {
        path.name.removesuffix(".customPermission-meta.xml"): path
        for path in custom_root.glob("*.customPermission-meta.xml")
    }
    selected: set[Path] = set()
    for permission_set in permission_root.glob("*.permissionset-meta.xml"):
        referenced = custom_permissions(permission_set)
        local_references = referenced.intersection(available)
        if not local_references:
            continue
        selected.add(permission_set)
        selected.update(available[name] for name in local_references)
    return sorted(selected)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="force-app")
    args = parser.parse_args()
    for path in dependencies(Path(args.root)):
        print(path.as_posix())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
