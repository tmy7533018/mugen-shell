// Package calendar is the sqlite-backed event store the shell's calendar module
// reads and writes, and the source for its due-event notifications.
package calendar

import (
	"crypto/rand"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	_ "modernc.org/sqlite"
)

const schema = `
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
`

// Bumping user_version to this marks the one-shot events.json import as done.
const legacyMigrated = 1

// Rows are ordered so all-day events lead the day, matching the shell's layout.
const orderClause = `ORDER BY date, CASE WHEN time = '' THEN 0 ELSE 1 END, time`

type Event struct {
	ID    string `json:"id"`
	Date  string `json:"date"`
	Time  string `json:"time"`
	Title string `json:"title"`
}

type Store struct {
	db   *sql.DB
	path string
}

func dataHome() string {
	if dir := os.Getenv("XDG_DATA_HOME"); dir != "" {
		return dir
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ".local/share"
	}
	return filepath.Join(home, ".local", "share")
}

// DefaultPath is where the shell and the notifier both expect the database.
func DefaultPath() string {
	return filepath.Join(dataHome(), "mugen-shell", "calendar.db")
}

func legacyJSONPath() string {
	return filepath.Join(dataHome(), "mugen-shell", "events.json")
}

// Open creates the database and schema if needed, and imports events.json once.
func Open(path string) (*Store, error) {
	if path == "" {
		path = DefaultPath()
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, err
	}

	// The driver defaults busy_timeout to 0, and the notify timer runs every minute.
	db, err := sql.Open("sqlite", path+"?_pragma=journal_mode(WAL)&_pragma=busy_timeout(5000)")
	if err != nil {
		return nil, err
	}
	if _, err := db.Exec(schema); err != nil {
		db.Close()
		return nil, err
	}

	s := &Store{db: db, path: path}
	if err := s.migrateLegacy(); err != nil {
		db.Close()
		return nil, err
	}
	return s, nil
}

func (s *Store) Close() error { return s.db.Close() }

// An empty table is no proof the import never ran, so a flag records it.
func (s *Store) migrateLegacy() error {
	var version int
	if err := s.db.QueryRow("PRAGMA user_version").Scan(&version); err != nil {
		return err
	}
	if version >= legacyMigrated {
		return nil
	}

	var count int
	if err := s.db.QueryRow("SELECT COUNT(*) FROM events").Scan(&count); err != nil {
		return err
	}

	raw, readErr := os.ReadFile(legacyJSONPath())
	if errors.Is(readErr, os.ErrNotExist) || count > 0 {
		return s.markMigrated()
	}
	// Present but unreadable: leave the flag clear so a later run retries.
	if readErr != nil {
		return nil
	}

	var legacy struct {
		Events []Event `json:"events"`
	}
	if err := json.Unmarshal(raw, &legacy); err != nil {
		return nil
	}

	for _, e := range legacy.Events {
		if e.ID == "" || e.Date == "" || e.Title == "" {
			continue
		}
		s.db.Exec("INSERT OR IGNORE INTO events (id, date, time, title) VALUES (?, ?, ?, ?)",
			e.ID, e.Date, e.Time, e.Title)
	}
	return s.markMigrated()
}

func (s *Store) markMigrated() error {
	_, err := s.db.Exec(fmt.Sprintf("PRAGMA user_version = %d", legacyMigrated))
	return err
}

func (s *Store) Path() string { return s.path }

func (s *Store) ListRange(start, end string) ([]Event, error) {
	return s.query("SELECT id, date, time, title FROM events WHERE date >= ? AND date <= ? "+orderClause, start, end)
}

func (s *Store) ListToday() ([]Event, error) {
	today := time.Now().Format("2006-01-02")
	return s.query("SELECT id, date, time, title FROM events WHERE date = ? "+orderClause, today)
}

func (s *Store) query(q string, args ...any) ([]Event, error) {
	rows, err := s.db.Query(q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	events := []Event{}
	for rows.Next() {
		var e Event
		if err := rows.Scan(&e.ID, &e.Date, &e.Time, &e.Title); err != nil {
			return nil, err
		}
		events = append(events, e)
	}
	return events, rows.Err()
}

func (s *Store) Add(date, eventTime, title string) (string, error) {
	id, err := newID()
	if err != nil {
		return "", err
	}
	_, err = s.db.Exec("INSERT INTO events (id, date, time, title) VALUES (?, ?, ?, ?)",
		id, date, eventTime, title)
	return id, err
}

func (s *Store) Delete(id string) (int64, error) {
	res, err := s.db.Exec("DELETE FROM events WHERE id = ?", id)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}

func (s *Store) Update(id, title, eventTime string) (int64, error) {
	res, err := s.db.Exec(
		"UPDATE events SET title = ?, time = ?, modified_at = unixepoch() WHERE id = ?",
		title, eventTime, id)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}

// Matches python's secrets.token_urlsafe(9): 9 random bytes, unpadded base64url.
func newID() (string, error) {
	buf := make([]byte, 9)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}
