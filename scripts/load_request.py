#!/usr/bin/env python3
"""Reload canonical request fields from Salesforce so GitHub input truncation cannot drop the requirement."""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import urllib.request

SF_COMMAND = shutil.which("sf") or shutil.which("sf.cmd") or "sf"


def load_with_cli(request_id: str, target_org: str) -> dict:
    path = f"/services/data/v62.0/sobjects/AI_Refactor_Request__c/{request_id}"
    result = subprocess.run(
        [
            SF_COMMAND,
            "api",
            "request",
            "rest",
            path,
            "--target-org",
            target_org,
            "--json",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    response = json.loads(result.stdout)
    return (response.get("result") or {}).get("body") or response.get("body") or response


def load_with_token(request_id: str, instance: str, token: str) -> dict:
    url = instance.rstrip("/") + "/services/data/v62.0/sobjects/AI_Refactor_Request__c/" + request_id
    request = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--request-id", required=True)
    parser.add_argument("--out", default="request.json")
    parser.add_argument("--target-org", default=os.environ.get("SF_CONTROL_TARGET_ORG"))
    args = parser.parse_args()
    instance = os.environ.get("SF_CONTROL_INSTANCE_URL")
    token = os.environ.get("SF_CONTROL_ACCESS_TOKEN")
    if args.target_org:
        payload = load_with_cli(args.request_id, args.target_org)
    elif instance and token:
        payload = load_with_token(args.request_id, instance, token)
    else:
        print(
            "A control-plane target org or access token is required to load the Salesforce request.",
            file=sys.stderr,
        )
        return 2
    slim = {
        "referenceId": payload.get("Name"),
        "repository": payload.get("Repository__c"),
        "sourceBranch": payload.get("Source_Branch__c"),
        "componentPath": payload.get("Component_Path__c"),
        "requirement": payload.get("Requirement__c"),
        "targetEnvironment": payload.get("Target_Environment__c"),
        "requestId": payload.get("Id"),
    }
    open(args.out, "w", encoding="utf-8").write(json.dumps(slim))
    print(json.dumps(slim))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
