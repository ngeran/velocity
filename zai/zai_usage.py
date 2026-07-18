#!/usr/bin/env python3
"""
zai_usage.py — polls Z.ai's GLM Coding Plan quota endpoint, fires desktop
notifications at 50/75/90/100% for both the 5h session window and the
7-day weekly window, and prints a single-line JSON summary to stdout for
Quickshell to consume.

Endpoint is undocumented in Z.ai's public API reference but is the same
one their subscription-management UI uses (works with API keys, not just
OAuth): GET https://api.z.ai/api/monitor/usage/quota/limit

API key resolution order:
  1. $ZAI_API_KEY
  2. $GLM_API_KEY
  3. ~/.config/zai/api_key  (plain text file, first line)

State (last-notified thresholds per reset cycle) persists at
~/.cache/zai-usage/state.json so we don't spam a notification every
poll once a threshold is crossed, but do re-arm on the next cycle.
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error
import subprocess
from pathlib import Path

API_URL = "https://api.z.ai/api/monitor/usage/quota/limit"
THRESHOLDS = (50, 75, 90, 100)
STATE_PATH = Path.home() / ".cache" / "zai-usage" / "state.json"
KEY_FILE = Path.home() / ".config" / "zai" / "api_key"

# unit/number pairs from the API distinguish session vs weekly windows
SESSION_UNIT_NUMBER = (3, 5)   # 5-hour rolling window
WEEKLY_UNIT_NUMBER = (6, 7)    # 7-day rolling window


def resolve_api_key() -> str | None:
    key = os.environ.get("ZAI_API_KEY") or os.environ.get("GLM_API_KEY")
    if key:
        return key.strip()
    if KEY_FILE.exists():
        try:
            return KEY_FILE.read_text().strip().splitlines()[0]
        except Exception:
            return None
    return None


def fetch_quota(api_key: str) -> dict:
    req = urllib.request.Request(
        API_URL,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))


def load_state() -> dict:
    if STATE_PATH.exists():
        try:
            return json.loads(STATE_PATH.read_text())
        except Exception:
            return {}
    return {}


def save_state(state: dict) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(state))


def notify(summary: str, body: str, urgency: str = "normal") -> None:
    try:
        subprocess.run(
            [
                "notify-send",
                "-a", "Z.ai Usage",
                "-u", urgency,
                "-i", "network-transmit-receive",
                summary,
                body,
            ],
            check=False,
        )
    except FileNotFoundError:
        pass


def crossed_thresholds(pct: float, already_notified: list[int]) -> list[int]:
    hits = [t for t in THRESHOLDS if pct >= t and t not in already_notified]
    return sorted(hits)


def format_reset(epoch_ms: int | None) -> str:
    if not epoch_ms:
        return "unknown"
    remaining = epoch_ms / 1000 - time.time()
    if remaining <= 0:
        return "now"
    hrs = int(remaining // 3600)
    mins = int((remaining % 3600) // 60)
    if hrs >= 24:
        days = hrs // 24
        hrs = hrs % 24
        return f"{days}d {hrs}h"
    if hrs > 0:
        return f"{hrs}h {mins}m"
    return f"{mins}m"


def process_window(name: str, limit: dict, state: dict, urgency_at_100: bool = True) -> dict:
    pct = float(limit.get("percentage", 0))
    reset_ms = limit.get("nextResetTime")
    key = name.lower()

    cycle_state = state.setdefault(key, {"resetTime": None, "notified": []})

    # new cycle detected -> re-arm all thresholds
    if cycle_state.get("resetTime") != reset_ms:
        cycle_state["resetTime"] = reset_ms
        cycle_state["notified"] = []

    hits = crossed_thresholds(pct, cycle_state["notified"])
    for t in hits:
        urgency = "critical" if (t == 100 and urgency_at_100) else ("normal" if t < 90 else "critical")
        notify(
            f"Z.ai {name} quota: {t}%",
            f"{name} window at {pct:.0f}% used. Resets in {format_reset(reset_ms)}.",
            urgency=urgency,
        )
        cycle_state["notified"].append(t)

    return {
        "percentage": round(pct, 1),
        "currentValue": limit.get("currentValue"),
        "usage": limit.get("usage"),
        "remaining": limit.get("remaining"),
        "resetTime": reset_ms,
        "resetIn": format_reset(reset_ms),
    }


def main() -> int:
    api_key = resolve_api_key()
    if not api_key:
        print(json.dumps({"error": "No ZAI_API_KEY found. Set it in env or ~/.config/zai/api_key"}))
        return 1

    try:
        payload = fetch_quota(api_key)
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            print(json.dumps({"error": "API key invalid. Check your Z.ai API key."}))
        else:
            print(json.dumps({"error": f"Usage request failed (HTTP {e.code})."}))
        return 1
    except urllib.error.URLError:
        print(json.dumps({"error": "Usage request failed. Check your connection."}))
        return 1
    except json.JSONDecodeError:
        print(json.dumps({"error": "Usage response invalid. Try again later."}))
        return 1

    if not payload.get("success"):
        print(json.dumps({"error": "Usage response unsuccessful."}))
        return 1

    limits = payload.get("data", {}).get("limits", [])
    session_limit = None
    weekly_limit = None
    for lim in limits:
        if lim.get("type") != "TOKENS_LIMIT":
            continue
        pair = (lim.get("unit"), lim.get("number"))
        if pair == SESSION_UNIT_NUMBER:
            session_limit = lim
        elif pair == WEEKLY_UNIT_NUMBER:
            weekly_limit = lim

    state = load_state()
    result = {}

    if session_limit:
        result["session"] = process_window("Session (5h)", session_limit, state)
    if weekly_limit:
        result["weekly"] = process_window("Weekly", weekly_limit, state)

    save_state(state)

    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
