#!/usr/bin/env python3
"""Authenticated callback to Salesforce Apex REST. Requires a control-plane access token."""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

SF_COMMAND = shutil.which("sf") or shutil.which("sf.cmd") or "sf"

ALLOWED_KEYS = {
    "requestId",
    "referenceId",
    "workflowRunId",
    "status",
    "branch",
    "pullRequestNumber",
    "pullRequestUrl",
    "baseCommit",
    "outputCommit",
    "validationId",
    "validationStatus",
    "pmdStatus",
    "pmdResult",
    "validationResult",
    "testSummary",
    "summary",
    "errorSummary",
    "deploymentId",
    "deploymentStatus",
    "deploymentResult",
    "promptTemplate",
    "promptVersion",
    "aiModel",
    "aiExecutionId",
    "changedFiles",
    "completedAt",
}


def payload_from_args(args: argparse.Namespace) -> dict:
    data = {}
    for key in ALLOWED_KEYS:
        value = getattr(args, key, None)
        if value not in (None, ""):
            if key == "pullRequestNumber":
                data[key] = int(value)
            else:
                data[key] = value
    extra = args.payload_json
    if extra:
        parsed = json.loads(extra)
        for key, value in parsed.items():
            if key in ALLOWED_KEYS and value not in (None, ""):
                data[key] = value
    return data


def cli_error(response: subprocess.CompletedProcess) -> str:
    """Extract the Salesforce error text from an `sf --json` failure."""
    for stream in (response.stdout, response.stderr):
        if not stream:
            continue
        try:
            parsed = json.loads(stream)
        except json.JSONDecodeError:
            continue
        message = parsed.get("message") or parsed.get("error")
        if not message and isinstance(parsed.get("result"), dict):
            message = parsed["result"].get("message")
        if message:
            return str(message).strip()
    return ((response.stderr or "") + (response.stdout or "")).strip() or "no output"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-org", default=os.environ.get("SF_CONTROL_TARGET_ORG"))
    parser.add_argument("--instance-url", default=os.environ.get("SF_CONTROL_INSTANCE_URL"))
    parser.add_argument("--access-token", default=os.environ.get("SF_CONTROL_ACCESS_TOKEN"))
    for key in sorted(ALLOWED_KEYS):
        parser.add_argument(f"--{key.replace('_', '-')}" if False else f"--{key}", dest=key, default=None)
    parser.add_argument("--payload-json", default=None)
    args = parser.parse_args()
    body = payload_from_args(args)
    if args.target_org:
        handle = tempfile.NamedTemporaryFile("w", delete=False, suffix=".json")
        try:
            json.dump(body, handle)
            handle.close()
            response = subprocess.run(
                [
                    SF_COMMAND,
                    "api",
                    "request",
                    "rest",
                    "/services/apexrest/ai-refactor/v1/status",
                    "--target-org",
                    args.target_org,
                    "--method",
                    "POST",
                    "--body",
                    "@" + handle.name,
                    "--json",
                ],
                capture_output=True,
                text=True,
            )
            if response.returncode != 0:
                print(
                    "Salesforce callback failed with status "
                    f"{response.returncode}: {cli_error(response)}",
                    file=sys.stderr,
                )
                return 1
            print(response.stdout)
            return 0
        finally:
            Path(handle.name).unlink(missing_ok=True)
    if not args.instance_url or not args.access_token:
        print(
            "A control-plane target org or SF_CONTROL_INSTANCE_URL and "
            "SF_CONTROL_ACCESS_TOKEN are required.",
            file=sys.stderr,
        )
        return 2
    url = args.instance_url.rstrip("/") + "/services/apexrest/ai-refactor/v1/status"
    request = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": "Bearer " + args.access_token,
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            print(response.read().decode("utf-8"))
            return 0
    except urllib.error.HTTPError as exc:
        print(f"Salesforce callback failed: HTTP {exc.code}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
