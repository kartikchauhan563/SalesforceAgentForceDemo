#!/usr/bin/env python3
"""Gate Salesforce Code Analyzer / PMD JSON on configured severity."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def counts(payload) -> dict[str, int]:
    result = {"critical": 0, "high": 0, "medium": 0, "low": 0}
    violations = []
    if isinstance(payload, dict):
        violations = payload.get("violations") or payload.get("results") or []
        if isinstance(payload.get("result"), list):
            violations = payload["result"]
    elif isinstance(payload, list):
        violations = payload
    for item in violations:
        if not isinstance(item, dict):
            continue
        severity = str(item.get("severity") or item.get("priority") or "").lower()
        if severity in {"1", "critical", "error"}:
            result["critical"] += 1
        elif severity in {"2", "high", "warning"}:
            result["high"] += 1
        elif severity in {"3", "medium"}:
            result["medium"] += 1
        else:
            result["low"] += 1
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--out", default="static-analysis-summary.json")
    parser.add_argument("--fail-on-high", action="store_true", default=True)
    args = parser.parse_args()
    path = Path(args.input)
    payload = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    summary = counts(payload)
    summary["status"] = "Failed" if summary["critical"] or summary["high"] else "Succeeded"
    Path(args.out).write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary))
    if summary["status"] == "Failed":
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
