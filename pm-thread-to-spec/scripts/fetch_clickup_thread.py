#!/usr/bin/env python3
"""
Fetch a ClickUp v3 chat thread (parent message + all replies) given a URL.

URL forms supported:
  https://app.clickup.com/<team_id>/chat/r/<channel_hash>/t/<message_id>
  https://app.clickup.com/<team_id>/chat/<channel>/<message_id>   (older)

Outputs JSON to stdout: { parent: {...}, replies: [...], users: { uid: name } }

Token resolution order:
  1. CLICKUP_API_TOKEN env var (if already set in the environment)
  2. File at CLICKUP_ENV_FILE env var (if set)
  3. .env in the current working directory
  4. .env two levels up from this script (if the skill is vendored inside a repo)
Never prints the token. Never accepts it on the command line.
"""
from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

import requests
from dotenv import load_dotenv


URL_RE = re.compile(
    r"app\.clickup\.com/(?P<team>\d+)/chat/(?:r/)?(?P<channel>[^/]+)/(?:t/)?(?P<msg>\d+)"
)


def _env_token() -> str:
    # Check env first (already set by caller or shell export).
    for k in ("CLICKUP_API_TOKEN", "CLICKUP_TOKEN", "CLICKUP_API_KEY"):
        if os.getenv(k):
            return os.environ[k]
    # Load from a .env file; resolution order: CLICKUP_ENV_FILE > CWD/.env > script-relative fallback.
    here = Path(__file__).resolve()
    candidates = [
        Path(os.environ["CLICKUP_ENV_FILE"]) if "CLICKUP_ENV_FILE" in os.environ else None,
        Path.cwd() / ".env",
        here.parents[3] / ".env",  # if skill is vendored inside a repo
    ]
    for p in candidates:
        if p is not None and p.exists():
            load_dotenv(p, override=False)
            break
    for k in ("CLICKUP_API_TOKEN", "CLICKUP_TOKEN", "CLICKUP_API_KEY"):
        v = os.getenv(k)
        if v:
            return v
    sys.exit(
        "ERROR: no ClickUp token found. Set CLICKUP_API_TOKEN in your environment, "
        "point CLICKUP_ENV_FILE at your .env, or place a .env in the current directory."
    )


def _parse_url(url: str) -> tuple[str, str, str]:
    m = URL_RE.search(url)
    if not m:
        sys.exit(f"ERROR: could not parse ClickUp URL: {url}")
    return m.group("team"), m.group("channel"), m.group("msg")


def _resolve_users(headers: dict, team_id: str, ids: set[str]) -> dict[str, str]:
    out: dict[str, str] = {}
    try:
        r = requests.get("https://api.clickup.com/api/v2/team", headers=headers, timeout=15)
        if r.ok:
            for t in r.json().get("teams", []):
                if t.get("id") == team_id:
                    for m in t.get("members", []):
                        u = m.get("user", {})
                        uid = str(u.get("id"))
                        if uid in ids:
                            out[uid] = u.get("username") or uid
    except requests.RequestException:
        pass
    return out


def fetch(url: str) -> dict:
    team_id, _channel, msg_id = _parse_url(url)
    token = _env_token()
    headers = {"Authorization": token, "accept": "application/json"}

    # Parent message
    parent: dict | None = None
    # Try fetching via channel page (no direct single-message GET in v3)
    r = requests.get(
        f"https://api.clickup.com/api/v3/workspaces/{team_id}/chat/messages/{msg_id}/replies",
        headers=headers,
        params={"limit": 100},
        timeout=20,
    )
    if not r.ok:
        sys.exit(f"ERROR: ClickUp API {r.status_code}: {r.text[:200]}")
    j = r.json()
    replies = list(j.get("data", []))
    # Walk pagination
    while j.get("next_cursor"):
        r = requests.get(
            f"https://api.clickup.com/api/v3/workspaces/{team_id}/chat/messages/{msg_id}/replies",
            headers=headers,
            params={"limit": 100, "cursor": j["next_cursor"]},
            timeout=20,
        )
        if not r.ok:
            break
        j = r.json()
        replies.extend(j.get("data", []))

    # Look up parent: scan channel messages for the matching id (best-effort)
    if replies:
        channel = replies[0].get("parent_channel")
        if channel:
            cr = requests.get(
                f"https://api.clickup.com/api/v3/workspaces/{team_id}/chat/channels/{channel}/messages",
                headers=headers,
                params={"limit": 50},
                timeout=20,
            )
            if cr.ok:
                for m in cr.json().get("data", []):
                    if m.get("id") == msg_id:
                        parent = m
                        break

    # Order replies oldest-first for human reading
    replies.sort(key=lambda m: m.get("date", 0))

    uids = {str(parent.get("user_id"))} if parent else set()
    uids.update(str(r.get("user_id")) for r in replies if r.get("user_id"))
    users = _resolve_users(headers, team_id, {u for u in uids if u and u != "None"})

    return {
        "team_id": team_id,
        "parent_message_id": msg_id,
        "url": url,
        "parent": parent,
        "replies": replies,
        "users": users,
        "fetched_at": datetime.utcnow().isoformat() + "Z",
    }


def _md(thread: dict) -> str:
    """Render the thread as markdown for spec composition."""
    users = thread["users"]
    out: list[str] = []
    out.append(f"# ClickUp thread {thread['parent_message_id']}\n")
    out.append(f"Source: {thread['url']}\n")
    if thread.get("parent"):
        p = thread["parent"]
        uid = str(p.get("user_id"))
        ts = datetime.fromtimestamp(p.get("date", 0) / 1000).strftime("%Y-%m-%d %H:%M")
        out.append(f"\n## Parent\n[{ts}] **{users.get(uid, uid)}**\n\n{p.get('content','')}\n")
    out.append("\n## Replies\n")
    for r in thread["replies"]:
        uid = str(r.get("user_id"))
        ts = datetime.fromtimestamp(r.get("date", 0) / 1000).strftime("%Y-%m-%d %H:%M")
        out.append(f"\n### [{ts}] {users.get(uid, uid)}\n\n{r.get('content','')}\n")
    return "".join(out)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    url = argv[1]
    fmt = "markdown" if "--md" in argv else "json"
    thread = fetch(url)
    if fmt == "markdown":
        print(_md(thread))
    else:
        print(json.dumps(thread, indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
