#!/usr/bin/env python3
"""Claim a target OAuth session or update deployment status through authenticated Apex REST."""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
from pathlib import Path

SF_COMMAND = shutil.which("sf") or shutil.which("sf.cmd") or "sf"


def response_json(text: str) -> dict | None:
    start = text.find("{")
    if start < 0:
        return None
    try:
        return json.loads(text[start:])
    except json.JSONDecodeError:
        return None


def call(method: str, path: str, body: dict | None = None) -> dict:
    target_org = os.environ.get("SF_CONTROL_TARGET_ORG", "control-org")
    command = [
        SF_COMMAND,
        "api",
        "request",
        "rest",
        path,
        "--target-org",
        target_org,
        "--method",
        method,
    ]
    body_file = None
    if body is not None:
        handle = tempfile.NamedTemporaryFile("w", delete=False, suffix=".json")
        json.dump(body, handle)
        handle.close()
        body_file = handle.name
        command += ["--body", "@" + body_file]
    try:
        completed = subprocess.run(command, capture_output=True, text=True)
    finally:
        if body_file:
            Path(body_file).unlink(missing_ok=True)

    parsed = response_json(completed.stdout) or response_json(completed.stderr)
    if parsed is None:
        detail = (completed.stderr or completed.stdout or "no output").strip()
        raise RuntimeError(f"Control-org request to {path} failed: {detail}")
    if parsed.get("success") is False:
        raise RuntimeError(
            f"Control-org request to {path} was rejected: {parsed.get('message')}"
        )
    if completed.returncode != 0 and "message" in parsed:
        raise RuntimeError(f"Control-org request to {path} failed: {parsed['message']}")
    return parsed


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    claim = sub.add_parser("claim")
    claim.add_argument("--request-id", required=True)

    status = sub.add_parser("status")
    status.add_argument("--request-id", required=True)
    status.add_argument("--workflow-run-id")
    status.add_argument("--status", required=True)
    status.add_argument("--validation-id")
    status.add_argument("--deployment-id")
    status.add_argument("--result")
    status.add_argument("--error-message")

    args = parser.parse_args()
    try:
        if args.command == "claim":
            request_id = urllib.parse.quote(args.request_id, safe="")
            result = call("GET", f"/services/apexrest/oauth-deploy/v1/claim?requestId={request_id}")
        else:
            body = {
                "requestId": args.request_id,
                "workflowRunId": args.workflow_run_id,
                "status": args.status,
                "validationId": args.validation_id,
                "deploymentId": args.deployment_id,
                "result": args.result,
                "errorMessage": args.error_message,
            }
            result = call(
                "POST",
                "/services/apexrest/oauth-deploy/v1/status",
                {key: value for key, value in body.items() if value not in (None, "")},
            )
        print(json.dumps(result))
        return 0
    except (RuntimeError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
