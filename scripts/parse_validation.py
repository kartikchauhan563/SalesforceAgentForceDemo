#!/usr/bin/env python3
"""Summarize Salesforce CLI --json validation output without leaking secrets."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

SECRET_RE = re.compile(r"(bearer\s+[a-z0-9._\-]+|-----BEGIN[\\s\\S]+?-----END [A-Z ]+-----)", re.I)


def summarize(payload: dict) -> dict:
    result = payload.get("result") or payload
    details = result.get("details") or {}
    component_failures = details.get("componentFailures") or result.get("componentFailures") or []
    test_failures = (
        (details.get("runTestResult") or {}).get("failures")
        or result.get("tests")
        or []
    )
    tests_ran = (
        (details.get("runTestResult") or {}).get("numTestsRun")
        or result.get("numberTestsTotal")
        or 0
    )
    provider_message = (
        result.get("message")
        or result.get("errorMessage")
        or payload.get("message")
        or payload.get("errorMessage")
    )
    success = bool(result.get("success") or payload.get("status") == 0)
    failures = []
    for failure in component_failures[:20]:
        failures.append(
            f"{failure.get('fullName') or failure.get('fileName')}: {failure.get('problem')}"
        )
    test_names = []
    for failure in test_failures[:20]:
        if isinstance(failure, dict):
            test_names.append(f"{failure.get('name')}.{failure.get('methodName')}")
        else:
            test_names.append(str(failure))
    summary = {
        "success": success,
        "id": result.get("id"),
        "status": "Succeeded" if success else "Failed",
        "componentFailures": failures,
        "testFailures": test_names,
        "testsRun": tests_ran,
        "message": (
            "Salesforce validation succeeded."
            if success
            else (
                str(provider_message)
                if provider_message
                else f"Salesforce validation failed because {len(test_names) or len(failures)} check(s) failed."
            )
        ),
    }
    return summary


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--out", default="validation-summary.json")
    args = parser.parse_args()
    raw = Path(args.input).read_text(encoding="utf-8")
    payload = json.loads(SECRET_RE.sub("[redacted]", raw))
    summary = summarize(payload)
    Path(args.out).write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(summary["message"])
    if summary.get("testFailures"):
        print("Tests:")
        print("\n".join(summary["testFailures"]))
    return 0 if summary["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
