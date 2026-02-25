#!/usr/bin/env python3
"""
devlog.py — post a session update to GitHub Issues + Trello in one shot.
Discord is handled automatically by the GitHub Action on push.

Usage:
    python3 scripts/devlog.py "title" "done: x\nfixed: y\nnext: z"
"""
import sys, json, urllib.request, urllib.parse, os

# ── Config ────────────────────────────────────────────────────────────────
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
env  = {}
with open(os.path.join(ROOT, ".env")) as f:
    for line in f:
        line = line.strip()
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            env[k] = v

GH_TOKEN     = env["GITHUB_PERSONAL_ACCESS_TOKEN"]
GH_REPO      = "readycheck-studios/steeleternal"
TRELLO_KEY   = env["TRELLO_API_KEY"]
TRELLO_TOKEN = env["TRELLO_TOKEN"]
TRELLO_DONE  = "699bc1029742d284f7866b4c"
TRELLO_NEXT  = "699bc1017da62874b77c5cef"

GH_HEADERS = {
    "Authorization": f"token {GH_TOKEN}",
    "Accept": "application/vnd.github.v3+json",
    "Content-Type": "application/json",
    "User-Agent": "SteelEternalBot/1.0",
}

# ── Args ──────────────────────────────────────────────────────────────────
if len(sys.argv) < 3:
    print("Usage: devlog.py <title> <body>")
    sys.exit(1)

title = sys.argv[1]
body  = sys.argv[2].replace("\\n", "\n")

# ── GitHub Issue ──────────────────────────────────────────────────────────
data = json.dumps({"title": title, "body": body}).encode()
req  = urllib.request.Request(
    f"https://api.github.com/repos/{GH_REPO}/issues",
    data=data, headers=GH_HEADERS, method="POST"
)
with urllib.request.urlopen(req) as r:
    issue = json.loads(r.read())
    print(f"GitHub Issue #{issue['number']}: {issue['html_url']}")

# ── Trello card → Done ────────────────────────────────────────────────────
params = urllib.parse.urlencode({
    "idList": TRELLO_DONE, "name": title, "desc": body,
    "key": TRELLO_KEY, "token": TRELLO_TOKEN,
}).encode()
req2 = urllib.request.Request("https://api.trello.com/1/cards", data=params, method="POST")
with urllib.request.urlopen(req2) as r:
    card = json.loads(r.read())
    print(f"Trello card: {card['shortUrl']}")

# ── Discord (via workflow_dispatch — runs from GitHub's servers) ──────────
data3 = json.dumps({
    "ref": "main",
    "inputs": {"title": title, "body": body}
}).encode()
req3 = urllib.request.Request(
    f"https://api.github.com/repos/{GH_REPO}/actions/workflows/discord-session-post.yml/dispatches",
    data=data3, headers=GH_HEADERS, method="POST"
)
with urllib.request.urlopen(req3) as r:
    print(f"Discord: workflow triggered (HTTP {r.status})")
