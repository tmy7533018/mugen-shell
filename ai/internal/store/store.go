// Package store persists conversations and messages in a local SQLite database.
package store

import (
	"database/sql"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"time"

	_ "modernc.org/sqlite"
)

const (
	settingCurrentConvID = "current_conversation_id"
	maxTitleLen          = 60
)

type Conversation struct {
	ID        int64  `json:"id"`
	Title     string `json:"title"`
	Model     string `json:"model"`
	Thinking  bool   `json:"thinking"`
	CreatedAt int64  `json:"created_at"`
	UpdatedAt int64  `json:"updated_at"`
}

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type Store struct {
	db *sql.DB
}

func Open(path string) (*Store, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, fmt.Errorf("mkdir state: %w", err)
	}
	db, err := sql.Open("sqlite", path+"?_pragma=foreign_keys(1)&_pragma=journal_mode(WAL)")
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}
	db.SetMaxOpenConns(1)
	s := &Store{db: db}
	if err := s.migrate(); err != nil {
		db.Close()
		return nil, fmt.Errorf("migrate: %w", err)
	}
	return s, nil
}

func (s *Store) Close() error { return s.db.Close() }

func (s *Store) migrate() error {
	stmts := []string{
		`CREATE TABLE IF NOT EXISTS conversations (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			title TEXT NOT NULL DEFAULT '',
			model TEXT NOT NULL DEFAULT '',
			created_at INTEGER NOT NULL,
			updated_at INTEGER NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS messages (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
			role TEXT NOT NULL,
			content TEXT NOT NULL,
			created_at INTEGER NOT NULL
		)`,
		`CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(conversation_id, created_at)`,
		`CREATE TABLE IF NOT EXISTS settings (
			key TEXT PRIMARY KEY,
			value TEXT NOT NULL
		)`,
	}
	for _, stmt := range stmts {
		if _, err := s.db.Exec(stmt); err != nil {
			return err
		}
	}
	// Backfill: older databases were created before the model column existed.
	if err := s.ensureColumn("conversations", "model", "TEXT NOT NULL DEFAULT ''"); err != nil {
		return err
	}
	if err := s.ensureColumn("conversations", "thinking", "INTEGER NOT NULL DEFAULT 0"); err != nil {
		return err
	}
	return nil
}

func (s *Store) ensureColumn(table, column, decl string) error {
	rows, err := s.db.Query(fmt.Sprintf("PRAGMA table_info(%s)", table))
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var cid int
		var name, ctype string
		var notnull, pk int
		var dflt sql.NullString
		if err := rows.Scan(&cid, &name, &ctype, &notnull, &dflt, &pk); err != nil {
			return err
		}
		if name == column {
			return nil
		}
	}
	if err := rows.Err(); err != nil {
		return err
	}
	_, err = s.db.Exec(fmt.Sprintf("ALTER TABLE %s ADD COLUMN %s %s", table, column, decl))
	return err
}

func nowUnix() int64 { return time.Now().Unix() }

func (s *Store) ListConversations() ([]Conversation, error) {
	rows, err := s.db.Query(`SELECT id, title, model, thinking, created_at, updated_at FROM conversations ORDER BY updated_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Conversation
	for rows.Next() {
		var c Conversation
		var thinking int
		if err := rows.Scan(&c.ID, &c.Title, &c.Model, &thinking, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, err
		}
		c.Thinking = thinking != 0
		out = append(out, c)
	}
	return out, rows.Err()
}

func (s *Store) CreateConversation(title, model string, thinking bool) (int64, error) {
	now := nowUnix()
	thinkingInt := 0
	if thinking {
		thinkingInt = 1
	}
	res, err := s.db.Exec(`INSERT INTO conversations (title, model, thinking, created_at, updated_at) VALUES (?, ?, ?, ?, ?)`,
		title, model, thinkingInt, now, now)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func (s *Store) GetConversation(id int64) (*Conversation, error) {
	row := s.db.QueryRow(`SELECT id, title, model, thinking, created_at, updated_at FROM conversations WHERE id = ?`, id)
	var c Conversation
	var thinking int
	if err := row.Scan(&c.ID, &c.Title, &c.Model, &thinking, &c.CreatedAt, &c.UpdatedAt); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	c.Thinking = thinking != 0
	return &c, nil
}

func (s *Store) UpdateConversationThinking(id int64, thinking bool) error {
	t := 0
	if thinking {
		t = 1
	}
	_, err := s.db.Exec(`UPDATE conversations SET thinking = ? WHERE id = ?`, t, id)
	return err
}

func (s *Store) UpdateConversationTitle(id int64, title string) error {
	_, err := s.db.Exec(`UPDATE conversations SET title = ? WHERE id = ?`, title, id)
	return err
}

func (s *Store) TouchConversation(id int64) error {
	_, err := s.db.Exec(`UPDATE conversations SET updated_at = ? WHERE id = ?`, nowUnix(), id)
	return err
}

func (s *Store) DeleteConversation(id int64) error {
	_, err := s.db.Exec(`DELETE FROM conversations WHERE id = ?`, id)
	return err
}

func (s *Store) AppendMessage(convID int64, role, content string) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	now := nowUnix()
	if _, err := tx.Exec(
		`INSERT INTO messages (conversation_id, role, content, created_at) VALUES (?, ?, ?, ?)`,
		convID, role, content, now,
	); err != nil {
		return err
	}
	if _, err := tx.Exec(`UPDATE conversations SET updated_at = ? WHERE id = ?`, now, convID); err != nil {
		return err
	}
	return tx.Commit()
}

func (s *Store) ListMessages(convID int64) ([]Message, error) {
	rows, err := s.db.Query(
		`SELECT role, content FROM messages WHERE conversation_id = ? ORDER BY created_at ASC, id ASC`,
		convID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Message
	for rows.Next() {
		var m Message
		if err := rows.Scan(&m.Role, &m.Content); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// RemoveLastMessage drops the most recent message (called when a chat fails
// after the user message was already persisted).
func (s *Store) RemoveLastMessage(convID int64) error {
	_, err := s.db.Exec(`DELETE FROM messages WHERE id = (
		SELECT id FROM messages WHERE conversation_id = ? ORDER BY created_at DESC, id DESC LIMIT 1
	)`, convID)
	return err
}

func (s *Store) GetCurrentConversationID() (int64, error) {
	row := s.db.QueryRow(`SELECT value FROM settings WHERE key = ?`, settingCurrentConvID)
	var v string
	if err := row.Scan(&v); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return 0, nil
		}
		return 0, err
	}
	id, err := strconv.ParseInt(v, 10, 64)
	if err != nil {
		return 0, nil
	}
	return id, nil
}

func (s *Store) SetCurrentConversationID(id int64) error {
	_, err := s.db.Exec(
		`INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value`,
		settingCurrentConvID, strconv.FormatInt(id, 10),
	)
	return err
}

func (s *Store) ClearCurrentConversationID() error {
	_, err := s.db.Exec(`DELETE FROM settings WHERE key = ?`, settingCurrentConvID)
	return err
}

// DeriveTitle picks a conversation title from an early user message.
func DeriveTitle(message string) string {
	for i, r := range message {
		if r == '\n' {
			message = message[:i]
			break
		}
	}
	if len([]rune(message)) <= maxTitleLen {
		return message
	}
	rs := []rune(message)
	return string(rs[:maxTitleLen]) + "…"
}
