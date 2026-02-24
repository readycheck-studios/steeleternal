#!/usr/bin/env python3
"""Post a commit dev-log to Discord #dev-updates."""
import os, json, urllib.request, sys

token   = os.environ["DISCORD_BOT_TOKEN"]
sha     = os.environ["COMMIT_SHA"][:7]
msg     = os.environ["COMMIT_MSG"].split("\n")[0]   # first line only
author  = os.environ["COMMIT_AUTHOR"]
repo    = os.environ["REPO"]
branch  = os.environ["BRANCH"]
ts      = os.environ["COMMIT_TIMESTAMP"]
files   = os.environ.get("FILES_CHANGED", "?")
url     = f"https://github.com/{repo}/commit/{os.environ['COMMIT_SHA']}"
channel = "1475632213037944912"

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
    f"https://discord.com/api/v10/channels/{channel}/messages",
    data=payload,
    headers={"Authorization": f"Bot {token}", "Content-Type": "application/json"},
    method="POST",
)
try:
    with urllib.request.urlopen(req) as r:
        print(f"Discord post OK \u2014 HTTP {r.status}")
except urllib.error.HTTPError as e:
    print(f"::error::Discord post failed HTTP {e.code}: {e.read().decode()}", file=sys.stderr)
    sys.exit(1)
