#!/usr/bin/env python3
"""Claim a target OAuth session or update deployment status through authenticated Apex REST."""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


def call(method: str, path: str, body: dict | None = None) -> dict:
    instance = os.environ.get("SF_CONTROL_INSTANCE_URL", "").rstrip("/")
    token = os.environ.get("SF_CONTROL_ACCESS_TOKEN", "")
    if not instance or not token:
        raise RuntimeError("Control-org instance URL and access token are required.")
    request = urllib.request.Request(
        instance + path,
        data=None if body is None else json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": "Bearer " + token,
            "Content-Type": "application/json",
        },
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8")
        raise RuntimeError(f"Control-org request failed with HTTP {exc.code}: {detail}") from exc


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
