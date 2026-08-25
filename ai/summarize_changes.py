#!/usr/bin/env python3
"""Produce a compact AI change summary for Salesforce callbacks. Never logs secrets."""
from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

SECRET_RE = re.compile(r"(bearer\s+[a-z0-9._\-]+|-----BEGIN [A-Z ]+-----)", re.I)


def git_names(base: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", base],
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--ai-summary", default="ai-summary.json")
    parser.add_argument("--out", default="ai-summary.json")
    args = parser.parse_args()
    summary = {}
    path = Path(args.ai_summary)
    if path.exists():
        summary = json.loads(path.read_text(encoding="utf-8"))
    files = git_names(args.base)
    summary["filesChanged"] = files
    summary["testsChanged"] = [name for name in files if "test" in name.lower()]
    text = json.dumps(summary)
    text = SECRET_RE.sub("[redacted]", text)
    Path(args.out).write_text(text, encoding="utf-8")
    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
