#!/usr/bin/env python3
"""SQLite-backed calendar event storage for mugen-shell.

Subcommands:
  init                                 Ensure DB exists; migrate legacy events.json once.
  list-range --start YYYY-MM-DD --end YYYY-MM-DD    Events in [start, end].
  list-today                           Today's events.
  add --date YYYY-MM-DD --title T [--time HH:MM]    Insert an event, prints id.
  delete --id ID                       Remove event by id.
"""

import argparse
import json
import os
import secrets
import sqlite3
import sys
import traceback
from datetime import datetime


DATA_HOME = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
DB_PATH = os.path.join(DATA_HOME, "mugen-shell", "calendar.db")
LEGACY_JSON = os.path.join(DATA_HOME, "mugen-shell", "events.json")

SCHEMA = """
CREATE TABLE IF NOT EXISTS events (
    id           TEXT PRIMARY KEY,
    date         TEXT NOT NULL,
    time         TEXT NOT NULL DEFAULT '',
    title        TEXT NOT NULL,
    description  TEXT NOT NULL DEFAULT '',
    source       TEXT NOT NULL DEFAULT 'local',
    remote_id    TEXT,
    remote_etag  TEXT,
    synced_at    INTEGER,
    modified_at  INTEGER NOT NULL DEFAULT (unixepoch()),
    rrule        TEXT,
    created_at   INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS events_by_date ON events(date);
CREATE INDEX IF NOT EXISTS events_by_remote ON events(remote_id) WHERE remote_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS events_modified ON events(modified_at);

CREATE TABLE IF NOT EXISTS sync_state (
    source       TEXT PRIMARY KEY,
    last_sync    INTEGER,
    sync_token   TEXT,
    display_name TEXT
);
"""


def gen_id() -> str:
    return secrets.token_urlsafe(9)


def open_db() -> sqlite3.Connection:
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.executescript(SCHEMA)
    return conn


def event_to_dict(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "date": row["date"],
        "time": row["time"] or "",
        "title": row["title"],
    }


def maybe_migrate_legacy(conn: sqlite3.Connection) -> None:
    if not os.path.exists(LEGACY_JSON):
        return
    if conn.execute("SELECT COUNT(*) FROM events").fetchone()[0] > 0:
        return
    try:
        with open(LEGACY_JSON, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError):
        return
    for e in data.get("events") or []:
        if not all(e.get(k) for k in ("id", "date", "title")):
            continue
        try:
            conn.execute(
                "INSERT OR IGNORE INTO events (id, date, time, title) VALUES (?, ?, ?, ?)",
                (e["id"], e["date"], e.get("time") or "", e["title"]),
            )
        except sqlite3.Error:
            continue
    conn.commit()


def cmd_init(_args) -> None:
    conn = open_db()
    maybe_migrate_legacy(conn)
    print(json.dumps({"db": DB_PATH, "ok": True}))


def cmd_list_range(args) -> None:
    conn = open_db()
    maybe_migrate_legacy(conn)
    rows = conn.execute(
        "SELECT id, date, time, title FROM events "
        "WHERE date >= ? AND date <= ? "
        "ORDER BY date, CASE WHEN time = '' THEN 0 ELSE 1 END, time",
        (args.start, args.end),
    ).fetchall()
    print(json.dumps({"events": [event_to_dict(r) for r in rows]}))


def cmd_list_today(_args) -> None:
    conn = open_db()
    maybe_migrate_legacy(conn)
    today = datetime.now().strftime("%Y-%m-%d")
    rows = conn.execute(
        "SELECT id, date, time, title FROM events WHERE date = ? "
        "ORDER BY CASE WHEN time = '' THEN 0 ELSE 1 END, time",
        (today,),
    ).fetchall()
    print(json.dumps({"events": [event_to_dict(r) for r in rows]}))


def cmd_add(args) -> None:
    conn = open_db()
    eid = gen_id()
    conn.execute(
        "INSERT INTO events (id, date, time, title) VALUES (?, ?, ?, ?)",
        (eid, args.date, args.time or "", args.title),
    )
    conn.commit()
    print(json.dumps({"id": eid, "ok": True}))


def cmd_delete(args) -> None:
    conn = open_db()
    cur = conn.execute("DELETE FROM events WHERE id = ?", (args.id,))
    conn.commit()
    print(json.dumps({"deleted": cur.rowcount, "ok": True}))


def cmd_update(args) -> None:
    conn = open_db()
    cur = conn.execute(
        "UPDATE events SET title = ?, time = ?, modified_at = unixepoch() WHERE id = ?",
        (args.title, args.time or "", args.id),
    )
    conn.commit()
    print(json.dumps({"updated": cur.rowcount, "ok": True}))


def main() -> int:
    parser = argparse.ArgumentParser(description="mugen-shell calendar event storage CLI")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_init = sub.add_parser("init", help="Ensure DB exists and migrate legacy JSON")
    p_init.set_defaults(func=cmd_init)

    p_range = sub.add_parser("list-range", help="List events between two dates")
    p_range.add_argument("--start", required=True)
    p_range.add_argument("--end", required=True)
    p_range.set_defaults(func=cmd_list_range)

    p_today = sub.add_parser("list-today", help="List today's events")
    p_today.set_defaults(func=cmd_list_today)

    p_add = sub.add_parser("add", help="Insert an event")
    p_add.add_argument("--date", required=True)
    p_add.add_argument("--time", default="")
    p_add.add_argument("--title", required=True)
    p_add.set_defaults(func=cmd_add)

    p_del = sub.add_parser("delete", help="Delete an event by id")
    p_del.add_argument("--id", required=True)
    p_del.set_defaults(func=cmd_delete)

    p_update = sub.add_parser("update", help="Update an event's title and time")
    p_update.add_argument("--id", required=True)
    p_update.add_argument("--title", required=True)
    p_update.add_argument("--time", default="")
    p_update.set_defaults(func=cmd_update)

    args = parser.parse_args()
    try:
        args.func(args)
        return 0
    except sqlite3.Error as e:
        print(json.dumps({"error": str(e), "ok": False}), file=sys.stderr)
        return 1
    except Exception:
        traceback.print_exc(file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
