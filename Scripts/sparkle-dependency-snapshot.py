#!/usr/bin/env python3
"""Create a GitHub dependency snapshot from the pinned Sparkle version."""

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("sha", help="Commit containing the lockfile")
parser.add_argument("job_id", help="GitHub Actions run ID")
args = parser.parse_args()

root = Path(__file__).resolve().parent.parent
pins = json.loads((root / "Package.resolved").read_text())["pins"]
if len(pins) != 1 or pins[0]["identity"] != "sparkle":
    raise SystemExit("Update dependency submission when adding another Swift package.")
pin = pins[0]
if pin["location"].removesuffix(".git") != "https://github.com/sparkle-project/Sparkle":
    raise SystemExit("Unexpected Sparkle source in Package.resolved.")

snapshot = {
    "version": 0,
    "sha": args.sha,
    "ref": "refs/heads/main",
    "job": {"id": args.job_id, "correlator": "sparkle-dependency-graph"},
    "detector": {
        "name": "stretchbreak-sparkle-lockfile",
        "version": "1.0.0",
        "url": "https://github.com/tomaskubat/stretch-break",
    },
    "scanned": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "manifests": {
        "Package.resolved": {
            "name": "Package.resolved",
            "file": {"source_location": "Package.resolved"},
            "resolved": {
                "github.com/sparkle-project/Sparkle": {
                    "package_url": "pkg:swift/github.com/sparkle-project/Sparkle@" + pin["state"]["version"],
                    "relationship": "direct",
                    "scope": "runtime",
                    "dependencies": [],
                }
            },
        }
    },
}
print(json.dumps(snapshot))
