#!/usr/bin/env python3
"""Post a session summary embed to Discord via webhook."""
import os, json, urllib.request, sys

webhook = os.environ["DISCORD_WEBHOOK_URL"]
title   = os.environ["TITLE"]
body    = os.environ["BODY"]

payload = json.dumps({
    "embeds": [{
        "title": f"Steel Eternal \u2014 {title}",
        "description": body,
        "color": 0xF49E0B,
        "footer": {"text": "readycheck-studios/steeleternal"}
    }]
}).encode()

req = urllib.request.Request(
    webhook, data=payload,
    headers={"Content-Type": "application/json"},
    method="POST"
)
try:
    with urllib.request.urlopen(req) as r:
        print(f"Discord OK \u2014 {r.status}")
except urllib.error.HTTPError as e:
    print(f"::error::Discord {e.code}: {e.read().decode()}", file=sys.stderr)
    sys.exit(1)
