#!/usr/bin/env python3
"""Fire desktop notifications for today's mugen-shell calendar events.

Run periodically (e.g. every minute via systemd timer). Events with a time
fire when the current minute matches the event time. All-day events fire
once at 08:00. State of fired notifications is kept in
$XDG_STATE_HOME/mugen-shell/notified.json to prevent duplicates.
"""

import json
import os
import subprocess
import sys
from datetime import datetime, timedelta


def paths():
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    state_home = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    events = os.path.join(data_home, "mugen-shell", "events.json")
    fired = os.path.join(state_home, "mugen-shell", "notified.json")
    return events, fired


def load_json(path, default):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return default


def save_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f)


def notify(summary, body):
    subprocess.run(
        ["notify-send", "-a", "mugen-shell", "-i", "x-office-calendar", summary, body],
        check=False,
    )


def prune_old_fired(fired_set, now):
    cutoff = now - timedelta(days=7)
    cleaned = set()
    for key in fired_set:
        date_part = key.split(":", 1)[0]
        try:
            if datetime.strptime(date_part, "%Y-%m-%d") >= cutoff:
                cleaned.add(key)
        except ValueError:
            continue
    return cleaned


def main():
    events_path, fired_path = paths()
    events_data = load_json(events_path, {"events": []})
    fired_data = load_json(fired_path, {"fired": []})
    fired_set = set(fired_data.get("fired", []))

    now = datetime.now()
    today = now.strftime("%Y-%m-%d")
    current_hm = now.strftime("%H:%M")

    new_keys = []
    for event in events_data.get("events", []):
        if event.get("date") != today:
            continue

        eid = event.get("id", "")
        title = event.get("title", "")
        etime = event.get("time", "")
        if not eid or not title:
            continue

        key = f"{today}:{eid}"
        if key in fired_set:
            continue

        if etime:
            if etime == current_hm:
                notify("Mugen Calendar", f"{etime} — {title}")
                new_keys.append(key)
        else:
            if current_hm >= "08:00":
                notify("Mugen Calendar", f"Today — {title}")
                new_keys.append(key)

    if new_keys:
        fired_set.update(new_keys)
        fired_set = prune_old_fired(fired_set, now)
        save_json(fired_path, {"fired": sorted(fired_set)})


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
