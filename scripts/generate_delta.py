#!/usr/bin/env python3
"""Generate a Salesforce-aware delta directory and package.xml from a git range."""
from __future__ import annotations

import argparse
import shutil
import subprocess
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

TYPE_BY_DIR = {
    "classes": ("ApexClass", ".cls"),
    "triggers": ("ApexTrigger", ".trigger"),
    "lwc": ("LightningComponentBundle", None),
    "aura": ("AuraDefinitionBundle", None),
    "aiAuthoringBundles": ("AiAuthoringBundle", None),
    "flexipages": ("FlexiPage", ".flexipage-meta.xml"),
    "flows": ("Flow", ".flow-meta.xml"),
    "objects": ("CustomObject", ".object-meta.xml"),
    "permissionsets": ("PermissionSet", ".permissionset-meta.xml"),
    "layouts": ("Layout", ".layout-meta.xml"),
    "tabs": ("CustomTab", ".tab-meta.xml"),
    "staticresources": ("StaticResource", None),
    "pages": ("ApexPage", ".page"),
    "components": ("ApexComponent", ".component"),
}


def git_names(base: str, head: str) -> list[str]:
    subprocess.run(["git", "add", "-A"], check=True)
    result = subprocess.run(
        ["git", "diff", "--cached", "--name-only", base],
        check=True,
        capture_output=True,
        text=True,
    )
    if result.stdout.strip():
        return [line.strip().replace("\\", "/") for line in result.stdout.splitlines() if line.strip()]
    result = subprocess.run(
        ["git", "diff", "--name-only", f"{base}...{head}"],
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip().replace("\\", "/") for line in result.stdout.splitlines() if line.strip()]


def bundle_root(path: str, kind: str) -> str | None:
    parts = Path(path).parts
    if kind not in parts:
        return None
    idx = parts.index(kind)
    if len(parts) > idx + 1:
        return str(Path(*parts[: idx + 2])).replace("\\", "/")
    return None


def member_name(path: Path, md_type: str, suffix: str | None) -> str:
    if md_type in {"LightningComponentBundle", "AuraDefinitionBundle", "AiAuthoringBundle"}:
        return path.name
    name = path.name
    if suffix and name.endswith(suffix):
        return name[: -len(suffix)]
    for extra in (".cls-meta.xml", ".trigger-meta.xml", "-meta.xml"):
        if name.endswith(extra):
            return name[: -len(extra)]
    return path.stem


def classify(path: str) -> tuple[str, str, Path] | None:
    posix = path.replace("\\", "/")
    if not posix.startswith("force-app/"):
        return None
    parts = Path(posix).parts
    if "bots" in parts:
        return classify_bot(posix)
    for directory, (md_type, suffix) in TYPE_BY_DIR.items():
        if directory in parts:
            if md_type in {"LightningComponentBundle", "AuraDefinitionBundle", "AiAuthoringBundle"}:
                root = bundle_root(posix, directory)
                if not root:
                    return None
                return md_type, Path(root).name, Path(root)
            if directory == "objects":
                return classify_object(posix)
            return md_type, member_name(Path(posix), md_type, suffix), Path(posix)
    return None


def classify_bot(path: str) -> tuple[str, str, Path] | None:
    parts = Path(path).parts
    bot_idx = parts.index("bots")
    if len(parts) <= bot_idx + 2:
        return None
    bot_name = parts[bot_idx + 1]
    source = Path(path)
    filename = source.name
    if filename.endswith(".botVersion-meta.xml"):
        version = filename[: -len(".botVersion-meta.xml")]
        return "BotVersion", f"{bot_name}.{version}", source
    if filename.endswith(".bot-meta.xml"):
        return "Bot", bot_name, source
    return None


def classify_object(path: str) -> tuple[str, str, Path] | None:
    parts = Path(path).parts
    obj_idx = parts.index("objects")
    if len(parts) <= obj_idx + 1:
        return None
    object_name = parts[obj_idx + 1]
    remainder = parts[obj_idx + 2 :]
    file_path = Path(path)
    if not remainder:
        return "CustomObject", object_name, file_path
    child = remainder[0]
    mapping = {
        "fields": "CustomField",
        "recordTypes": "RecordType",
        "validationRules": "ValidationRule",
        "webLinks": "WebLink",
        "listViews": "ListView",
        "compactLayouts": "CompactLayout",
        "businessProcesses": "BusinessProcess",
        "fieldSets": "FieldSet",
    }
    if child in mapping and len(remainder) >= 2:
        member = remainder[1]
        for suffix in (".field-meta.xml", ".recordType-meta.xml", ".validationRule-meta.xml", "-meta.xml"):
            if member.endswith(suffix):
                member = member[: -len(suffix)]
                break
        return mapping[child], f"{object_name}.{member}", file_path
    return "CustomObject", object_name, Path(*parts[: obj_idx + 2])


def copy_with_meta(src: Path, dest_root: Path, repo: Path) -> None:
    if src.is_dir():
        target = dest_root / src.relative_to(repo)
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(src, target)
        return
    target = dest_root / src.relative_to(repo)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, target)
    meta = src.with_name(src.name + "-meta.xml")
    if not meta.exists():
        meta = Path(str(src) + "-meta.xml")
    if meta.exists() and meta.is_file():
        meta_target = dest_root / meta.relative_to(repo)
        meta_target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(meta, meta_target)


def write_package(members: dict[str, set[str]], dest: Path, api_version: str) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    pkg = ET.Element("Package", xmlns="http://soap.sforce.com/2006/04/metadata")
    for md_type in sorted(members):
        types = ET.SubElement(pkg, "types")
        for member in sorted(members[md_type]):
            ET.SubElement(types, "members").text = member
        ET.SubElement(types, "name").text = md_type
    ET.SubElement(pkg, "version").text = api_version
    ET.ElementTree(pkg).write(dest, encoding="utf-8", xml_declaration=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--out", default="delta")
    parser.add_argument("--api-version", default="62.0")
    args = parser.parse_args()
    repo = Path.cwd()
    out = repo / args.out
    if out.exists():
        shutil.rmtree(out)
    members: dict[str, set[str]] = defaultdict(set)
    for path in git_names(args.base, args.head):
        classified = classify(path)
        if not classified:
            continue
        md_type, member, source = classified
        abs_source = repo / source
        if abs_source.exists():
            copy_with_meta(abs_source, out, repo)
            members[md_type].add(member)
    write_package(members, out / "package" / "package.xml", args.api_version)
    print(f"delta_types={len(members)}")
    return 0 if members else 1


if __name__ == "__main__":
    raise SystemExit(main())
