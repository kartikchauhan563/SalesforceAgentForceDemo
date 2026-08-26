#!/usr/bin/env python3
"""Authenticate the control-plane Salesforce org and print an access token JSON blob."""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SF_COMMAND = shutil.which("sf") or shutil.which("sf.cmd") or "sf"


def write_key(raw: str) -> str:
    if not raw:
        raise SystemExit("JWT key is empty.")
    normalized = raw.replace("\\n", "\n")
    handle = tempfile.NamedTemporaryFile("w", delete=False, suffix=".key")
    handle.write(normalized)
    handle.close()
    return handle.name


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--alias", default="control-org")
    parser.add_argument("--client-id", default=os.environ.get("SF_CONTROL_CLIENT_ID"))
    parser.add_argument("--username", default=os.environ.get("SF_CONTROL_USERNAME"))
    parser.add_argument("--instance-url", default=os.environ.get("SF_CONTROL_INSTANCE_URL"))
    parser.add_argument("--jwt-key", default=os.environ.get("SF_CONTROL_JWT_KEY"))
    args = parser.parse_args()
    if not all([args.client_id, args.username, args.instance_url, args.jwt_key]):
        print("Control-plane Salesforce JWT variables are required.", file=sys.stderr)
        return 2
    key_file = write_key(args.jwt_key)
    try:
        # stdout is reserved for the JSON blob callers redirect into a file, so
        # keep the CLI's own success chatter off it.
        subprocess.run(
            [
                SF_COMMAND,
                "org",
                "login",
                "jwt",
                "--client-id",
                args.client_id,
                "--jwt-key-file",
                key_file,
                "--username",
                args.username,
                "--instance-url",
                args.instance_url,
                "--alias",
                args.alias,
            ],
            check=True,
            stdout=sys.stderr,
        )
        display = subprocess.run(
            [
                SF_COMMAND,
                "org",
                "display",
                "--target-org",
                args.alias,
                "--verbose",
                "--json",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        payload = json.loads(display.stdout)
        result = payload.get("result") or payload
        print(json.dumps({
            "accessToken": result.get("accessToken"),
            "instanceUrl": result.get("instanceUrl"),
        }))
        return 0
    finally:
        Path(key_file).unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
