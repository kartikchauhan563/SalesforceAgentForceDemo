#!/usr/bin/env python3
"""Reload canonical request fields from Salesforce so GitHub input truncation cannot drop the requirement."""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.request


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--request-id", required=True)
    parser.add_argument("--out", default="request.json")
    args = parser.parse_args()
    instance = os.environ.get("SF_CONTROL_INSTANCE_URL")
    token = os.environ.get("SF_CONTROL_ACCESS_TOKEN")
    if not instance or not token:
        print("Control-plane token is required to load the Salesforce request.", file=sys.stderr)
        return 2
    url = instance.rstrip("/") + "/services/data/v62.0/sobjects/AI_Refactor_Request__c/" + args.request_id
    request = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
    with urllib.request.urlopen(request, timeout=60) as response:
        payload = json.loads(response.read().decode("utf-8"))
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
