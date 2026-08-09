package history

import (
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/tmy7533018/mugen-ai/internal/attach"
	"github.com/tmy7533018/mugen-ai/internal/provider"
	"github.com/tmy7533018/mugen-ai/internal/store"
)

// 1x1 transparent PNG.
const onePixelPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

func TestTruncateKeepsUserLeading(t *testing.T) {
	// A tiny budget forces the drop to land mid-exchange.
	h := &History{maxTokens: 20}
	big := ""
	for i := 0; i < 40; i++ {
		big += "word "
	}
	h.messages = []provider.Message{
		{Role: "user", Content: big},
		{Role: "assistant", Content: big},
		{Role: "user", Content: big},
		{Role: "assistant", Content: "ok"},
	}
	h.truncateLocked()

	if len(h.messages) == 0 {
		t.Fatal("truncation emptied the conversation")
	}
	if h.messages[0].Role != "user" {
		t.Fatalf("first message must be user, got %q", h.messages[0].Role)
	}
}

func TestTruncateNoTokenCapLeavesUserLead(t *testing.T) {
	h := &History{maxTokens: 0}
	h.messages = []provider.Message{
		{Role: "assistant", Content: "stray"},
		{Role: "user", Content: "hi"},
		{Role: "assistant", Content: "hello"},
	}
	h.truncateLocked()

	if h.messages[0].Role != "user" {
		t.Fatalf("first message must be user, got %q", h.messages[0].Role)
	}
}

func newTestHistory(t *testing.T) (*History, *store.Store) {
	t.Helper()
	s, err := store.Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { s.Close() })
	h, err := New(s, "", 0)
	if err != nil {
		t.Fatalf("new history: %v", err)
	}
	return h, s
}

func seedExchange(t *testing.T, h *History, turns int) int64 {
	t.Helper()
	convID, err := h.NewConversation("m", false)
	if err != nil {
		t.Fatalf("new conversation: %v", err)
	}
	for i := 0; i < turns; i++ {
		if err := h.Add("user", fmt.Sprintf("q%d", i), "m", false); err != nil {
			t.Fatalf("add user: %v", err)
		}
		if err := h.Add("assistant", fmt.Sprintf("a%d", i), "m", false); err != nil {
			t.Fatalf("add assistant: %v", err)
		}
	}
	return convID
}

func TestAttachmentsSurviveReload(t *testing.T) {
	h, s := newTestHistory(t)
	data, err := base64.StdEncoding.DecodeString(onePixelPNG)
	if err != nil {
		t.Fatalf("decode fixture: %v", err)
	}
	path := filepath.Join(t.TempDir(), "shot.png")
	if err := os.WriteFile(path, data, 0o644); err != nil {
		t.Fatalf("write fixture: %v", err)
	}

	convID, err := h.NewConversation("m", false)
	if err != nil {
		t.Fatalf("new conversation: %v", err)
	}
	att, err := attach.Load([]string{path})
	if err != nil {
		t.Fatalf("load attachment: %v", err)
	}
	if err := h.AddWithAttachments("user", "what is this", "m", false, []string{path}, att); err != nil {
		t.Fatalf("add: %v", err)
	}

	stored, _ := s.ListMessages(convID)
	if len(stored) != 1 || len(stored[0].Attachments) != 1 || stored[0].Attachments[0] != path {
		t.Fatalf("attachment path not persisted: %+v", stored)
	}

	// Reload from the database rather than the in-memory copy.
	if _, err := h.NewConversation("m", false); err != nil {
		t.Fatalf("second conversation: %v", err)
	}
	if err := h.Switch(convID); err != nil {
		t.Fatalf("switch back: %v", err)
	}
	msgs := h.Messages()
	if len(msgs) != 1 || len(msgs[0].Images) != 1 {
		t.Fatalf("images not restored: %+v", msgs)
	}
	if msgs[0].Images[0].MediaType != "image/png" {
		t.Fatalf("media type: %q", msgs[0].Images[0].MediaType)
	}
}

func TestAttachmentsDroppedWhenFileIsGone(t *testing.T) {
	h, s := newTestHistory(t)
	convID, err := h.NewConversation("m", false)
	if err != nil {
		t.Fatalf("new conversation: %v", err)
	}
	missing := filepath.Join(t.TempDir(), "deleted.png")
	if err := s.AppendMessage(convID, "user", "look", []string{missing}); err != nil {
		t.Fatalf("append: %v", err)
	}

	if err := h.Switch(0); err != nil {
		t.Fatalf("switch away: %v", err)
	}
	if err := h.Switch(convID); err != nil {
		t.Fatalf("switch back: %v", err)
	}
	msgs := h.Messages()
	if len(msgs) != 1 || len(msgs[0].Images) != 0 {
		t.Fatalf("want the message with no images, got %+v", msgs)
	}
}

func TestTruncateFromDropsTailAndReloads(t *testing.T) {
	h, s := newTestHistory(t)
	convID := seedExchange(t, h, 3)

	msgs, err := s.ListMessages(convID)
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(msgs) != 6 {
		t.Fatalf("want 6 seeded messages, got %d", len(msgs))
	}

	// Rewind to the second user turn, which is what "edit q1" would do.
	removed, err := h.TruncateFrom(convID, msgs[2].ID)
	if err != nil {
		t.Fatalf("truncate: %v", err)
	}
	if removed != 4 {
		t.Fatalf("want 4 removed, got %d", removed)
	}

	left, err := s.ListMessages(convID)
	if err != nil {
		t.Fatalf("list after: %v", err)
	}
	if len(left) != 2 || left[0].Content != "q0" || left[1].Content != "a0" {
		t.Fatalf("unexpected remainder: %+v", left)
	}

	// The in-memory copy feeds the next turn, so a stale one would resend deleted messages.
	inMem := h.Messages()
	var contents []string
	for _, m := range inMem {
		if m.Role != "system" {
			contents = append(contents, m.Content)
		}
	}
	if len(contents) != 2 || contents[0] != "q0" || contents[1] != "a0" {
		t.Fatalf("in-memory history not reloaded: %+v", contents)
	}
}

func TestTruncateFromFirstMessageEmptiesConversation(t *testing.T) {
	h, s := newTestHistory(t)
	convID := seedExchange(t, h, 2)
	msgs, _ := s.ListMessages(convID)

	if _, err := h.TruncateFrom(convID, msgs[0].ID); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	left, _ := s.ListMessages(convID)
	if len(left) != 0 {
		t.Fatalf("want empty conversation, got %d", len(left))
	}
}

func TestTruncateFromUnknownMessageKeepsEverything(t *testing.T) {
	h, s := newTestHistory(t)
	convID := seedExchange(t, h, 2)
	before, _ := s.ListMessages(convID)

	removed, err := h.TruncateFrom(convID, 9999)
	if !errors.Is(err, store.ErrMessageNotInConversation) {
		t.Fatalf("want ErrMessageNotInConversation, got %v", err)
	}
	if removed != 0 {
		t.Fatalf("want 0 removed, got %d", removed)
	}
	after, _ := s.ListMessages(convID)
	if len(after) != len(before) {
		t.Fatalf("conversation changed: %d -> %d", len(before), len(after))
	}
}

func TestTruncateFromForeignMessageIsRejected(t *testing.T) {
	h, s := newTestHistory(t)
	foreign := seedExchange(t, h, 1)
	foreignMsgs, _ := s.ListMessages(foreign)

	target := seedExchange(t, h, 2)
	before, _ := s.ListMessages(target)

	removed, err := h.TruncateFrom(target, foreignMsgs[0].ID)
	if !errors.Is(err, store.ErrMessageNotInConversation) {
		t.Fatalf("want ErrMessageNotInConversation, got %v", err)
	}
	if removed != 0 {
		t.Fatalf("want 0 removed, got %d", removed)
	}
	after, _ := s.ListMessages(target)
	if len(after) != len(before) {
		t.Fatalf("conversation changed: %d -> %d", len(before), len(after))
	}
}

func TestTruncateFromOtherConversationIsScoped(t *testing.T) {
	h, s := newTestHistory(t)
	keep := seedExchange(t, h, 1)
	keepMsgs, _ := s.ListMessages(keep)

	target := seedExchange(t, h, 2)
	targetMsgs, _ := s.ListMessages(target)

	if _, err := h.TruncateFrom(target, targetMsgs[0].ID); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	still, _ := s.ListMessages(keep)
	if len(still) != len(keepMsgs) {
		t.Fatalf("other conversation was touched: %d -> %d", len(keepMsgs), len(still))
	}
}
