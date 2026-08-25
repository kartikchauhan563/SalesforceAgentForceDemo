#!/usr/bin/env python3
"""Discover Salesforce source files relevant to a natural-language requirement."""
from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOKEN_RE = re.compile(r"[A-Za-z][A-Za-z0-9_]{2,}")
SOURCE_SUFFIXES = {
    ".cls",
    ".trigger",
    ".js",
    ".html",
    ".css",
    ".xml",
    ".cmp",
    ".app",
    ".page",
}
STOP_WORDS = {
    "add",
    "and",
    "any",
    "can",
    "change",
    "code",
    "component",
    "create",
    "from",
    "have",
    "into",
    "make",
    "need",
    "new",
    "please",
    "requirement",
    "salesforce",
    "should",
    "that",
    "the",
    "this",
    "update",
    "with",
}


@dataclass(frozen=True)
class Candidate:
    path: str
    score: int
    reasons: tuple[str, ...]


def load_policy(root: Path = ROOT) -> dict:
    return json.loads((root / "ai" / "workspace-policy.json").read_text(encoding="utf-8"))


def normalize_tokens(value: str) -> set[str]:
    tokens: set[str] = set()
    for raw in TOKEN_RE.findall(value or ""):
        # Split identifiers such as LoanApplicationTriggerHandler.
        pieces = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", raw).replace("_", " ").split()
        for piece in [raw, *pieces]:
            lowered = piece.lower()
            if len(lowered) >= 3 and lowered not in STOP_WORDS:
                tokens.add(lowered)
    return tokens


def is_source_file(path: Path) -> bool:
    name = path.name.lower()
    return (
        path.suffix.lower() in SOURCE_SUFFIXES
        or name.endswith("-meta.xml")
        or name.endswith(".flow-meta.xml")
        or name.endswith(".object-meta.xml")
        or name.endswith(".field-meta.xml")
    )


def inventory(root: Path, allowed_prefixes: list[str]) -> list[Path]:
    found: set[Path] = set()
    for prefix in allowed_prefixes:
        base = root / prefix
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if path.is_file() and is_source_file(path) and path.stat().st_size <= 400_000:
                found.add(path)
    return sorted(found)


def score_file(root: Path, path: Path, tokens: set[str]) -> Candidate:
    rel = path.relative_to(root).as_posix()
    path_tokens = normalize_tokens(rel)
    path_matches = sorted(tokens & path_tokens)
    score = len(path_matches) * 20
    reasons: list[str] = []
    if path_matches:
        reasons.append("path:" + ",".join(path_matches))

    try:
        content = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        content = ""
    content_lower = content.lower()
    content_matches = [token for token in tokens if token in content_lower]
    score += len(content_matches) * 3
    if content_matches:
        reasons.append("content:" + ",".join(sorted(content_matches)[:8]))

    name = path.name.lower()
    if "test" in name:
        score -= 2
    if name.endswith("-meta.xml"):
        score -= 3
    return Candidate(rel, score, tuple(reasons))


def component_key(path: str) -> str:
    name = Path(path).name
    for suffix in (
        ".cls-meta.xml",
        ".trigger-meta.xml",
        ".js-meta.xml",
        "-meta.xml",
        ".cls",
        ".trigger",
        ".js",
        ".html",
        ".css",
    ):
        if name.endswith(suffix):
            return name[: -len(suffix)].lower()
    return Path(path).stem.lower()


def add_companions(ranked: list[Candidate], all_paths: list[str], limit: int) -> list[Candidate]:
    primary_count = max(1, limit // 2)
    selected = list(ranked[:primary_count])
    selected_paths = {item.path for item in selected}
    selected_keys = {component_key(item.path) for item in selected}
    for path in all_paths:
        if len(selected) >= limit:
            break
        key = component_key(path)
        is_test = key.endswith("test") and key[:-4] in selected_keys
        is_metadata = path.endswith("-meta.xml") and key in selected_keys
        is_bundle_file = "/lwc/" in path and key in selected_keys
        if (is_test or is_metadata or is_bundle_file) and path not in selected_paths:
            selected.append(Candidate(path, 1, ("companion",)))
            selected_paths.add(path)
    for candidate in ranked[primary_count:]:
        if len(selected) >= limit:
            break
        if candidate.path not in selected_paths:
            selected.append(candidate)
            selected_paths.add(candidate.path)
    return selected


def discover(
    requirement: str,
    root: Path = ROOT,
    limit: int = 16,
    minimum_score: int = 1,
) -> list[Candidate]:
    tokens = normalize_tokens(requirement)
    if not tokens:
        return []
    policy = load_policy(root)
    files = inventory(root, policy.get("allowed_prefixes", []))
    ranked = [score_file(root, path, tokens) for path in files]
    ranked = [item for item in ranked if item.score >= minimum_score]
    ranked.sort(key=lambda item: (-item.score, item.path))
    return add_companions(ranked, [p.relative_to(root).as_posix() for p in files], limit)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--requirement", required=True)
    parser.add_argument("--limit", type=int, default=16)
    parser.add_argument("--out")
    args = parser.parse_args()
    candidates = discover(args.requirement, Path.cwd(), args.limit)
    payload = [
        {"path": candidate.path, "score": candidate.score, "reasons": list(candidate.reasons)}
        for candidate in candidates
    ]
    text = json.dumps(payload, indent=2)
    if args.out:
        Path(args.out).write_text(text, encoding="utf-8")
    print(text)
    return 0 if candidates else 2


if __name__ == "__main__":
    raise SystemExit(main())
