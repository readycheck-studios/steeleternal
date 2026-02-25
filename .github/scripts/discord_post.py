#!/usr/bin/env python3
"""Post a commit dev-log to Discord #dev-updates via webhook."""
import os, json, urllib.request, sys

webhook = os.environ["DISCORD_WEBHOOK_URL"]
sha     = os.environ["COMMIT_SHA"][:7]
msg     = os.environ["COMMIT_MSG"].split("\n")[0]
author  = os.environ["COMMIT_AUTHOR"]
repo    = os.environ["REPO"]
branch  = os.environ["BRANCH"]
ts      = os.environ["COMMIT_TIMESTAMP"]
files   = os.environ.get("FILES_CHANGED", "?")
url     = f"https://github.com/{repo}/commit/{os.environ['COMMIT_SHA']}"

payload = json.dumps({
    "embeds": [{
        "title": "\U0001f527 New Push \u2014 Steel Eternal",
        "color": 15964171,
        "fields": [
            {"name": "Branch",        "value": f"`{branch}`",                                    "inline": True},
            {"name": "Files changed", "value": files,                                             "inline": True},
            {"name": "Author",        "value": author,                                            "inline": True},
            {"name": "Commit",        "value": f"`{sha}` \u2014 {msg}\n[View on GitHub]({url})", "inline": False},
        ],
        "footer":    {"text": repo},
        "timestamp": ts,
    }]
}).encode()

req = urllib.request.Request(
    webhook,
    data=payload,
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    with urllib.request.urlopen(req) as r:
        print(f"Discord post OK \u2014 HTTP {r.status}")
except urllib.error.HTTPError as e:
    print(f"::error::Discord post failed HTTP {e.code}: {e.read().decode()}", file=sys.stderr)
    sys.exit(1)
