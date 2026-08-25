#!/usr/bin/env python3
"""Summarize Salesforce CLI --json deploy output without leaking secrets."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

SECRET_RE = re.compile(r"(bearer\s+[a-z0-9._\-]+|-----BEGIN[\\s\\S]+?-----END [A-Z ]+-----)", re.I)


def summarize(payload: dict) -> dict:
    result = payload.get("result") or payload
    success = bool(result.get("success") or payload.get("status") == 0)
    details = result.get("details") or {}
    tests = details.get("runTestResult") or {}
    failures = tests.get("failures") or []
    summary = {
        "success": success,
        "id": result.get("id"),
        "status": "Succeeded" if success else "Failed",
        "testsRun": tests.get("numTestsRun") or 0,
        "testsFailed": len(failures),
        "coverage": (tests.get("codeCoverage") or [{}])[0].get("coverage")
        if isinstance(tests.get("codeCoverage"), list) and tests.get("codeCoverage")
        else None,
        "message": "Deployment succeeded." if success else "Deployment failed.",
        "testFailures": [
            f"{item.get('name')}.{item.get('methodName')}: {item.get('message')}"
            for item in failures[:20]
            if isinstance(item, dict)
        ],
    }
    return summary


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--out", default="deployment-summary.json")
    args = parser.parse_args()
    raw = SECRET_RE.sub("[redacted]", Path(args.input).read_text(encoding="utf-8"))
    summary = summarize(json.loads(raw))
    Path(args.out).write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(summary["message"])
    return 0 if summary["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
