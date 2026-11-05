package history

import (
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"unicode/utf8"

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
	if _, err := s.AppendMessage(convID, "user", "look", []string{missing}, ""); err != nil {
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

// The boundary the panel draws is only honest if it is the same arithmetic the
// truncation itself runs.
func TestDropCountMatchesTruncation(t *testing.T) {
	big := ""
	for i := 0; i < 40; i++ {
		big += "word "
	}
	msgs := []provider.Message{
		{Role: "user", Content: big},
		{Role: "assistant", Content: big},
		{Role: "user", Content: big},
		{Role: "assistant", Content: "ok"},
	}

	h := &History{maxTokens: 20}
	h.messages = append([]provider.Message(nil), msgs...)
	want := dropCount(msgs, h.max, h.maxTokens)
	h.truncateLocked()

	if got := len(msgs) - len(h.messages); got != want {
		t.Fatalf("dropCount said %d, truncation dropped %d", want, got)
	}
	if want == 0 {
		t.Fatal("the fixture must actually overflow the budget")
	}
}

func TestSwitchToTheCurrentConversationPicksUpAnotherWritersRows(t *testing.T) {
	path := filepath.Join(t.TempDir(), "history.db")
	daemonStore, err := store.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer daemonStore.Close()
	daemon, err := New(daemonStore, "", 0)
	if err != nil {
		t.Fatal(err)
	}
	convID, _ := daemon.NewConversation("m", false)
	_ = daemon.Add("user", "gui-q", "m", false)
	_ = daemon.AddAssistantTo(convID, "gui-a", "")

	cliStore, err := store.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	cli, err := New(cliStore, "", 0)
	if err != nil {
		t.Fatal(err)
	}
	_ = cli.Add("user", "cli-q", "m", false)
	_ = cli.Add("assistant", "cli-a", "m", false)
	cliStore.Close()

	if err := daemon.Switch(convID); err != nil {
		t.Fatal(err)
	}
	var got []string
	for _, m := range daemon.Messages() {
		got = append(got, m.Content)
	}
	if want := []string{"gui-q", "gui-a", "cli-q", "cli-a"}; fmt.Sprint(got) != fmt.Sprint(want) {
		t.Errorf("messages = %v, want %v", got, want)
	}
}

func TestSwitchPicksUpRowsWrittenDuringATurn(t *testing.T) {
	path := filepath.Join(t.TempDir(), "history.db")
	daemonStore, err := store.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer daemonStore.Close()
	daemon, err := New(daemonStore, "", 0)
	if err != nil {
		t.Fatal(err)
	}
	convID, _ := daemon.NewConversation("m", false)
	_ = daemon.Add("user", "gui-q1", "m", false)
	_ = daemon.AddAssistantTo(convID, "gui-a1", "")
	_ = daemon.Add("user", "gui-q2", "m", false)

	cliStore, err := store.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	cli, err := New(cliStore, "", 0)
	if err != nil {
		t.Fatal(err)
	}
	_ = cli.Add("user", "cli-q", "m", false)
	_ = cli.Add("assistant", "cli-a", "m", false)
	cliStore.Close()

	_ = daemon.AddAssistantTo(convID, "gui-a2", "")
	if err := daemon.Switch(convID); err != nil {
		t.Fatal(err)
	}
	var got []string
	for _, m := range daemon.Messages() {
		got = append(got, m.Content)
	}
	if want := []string{"gui-q1", "gui-a1", "gui-q2", "cli-q", "cli-a", "gui-a2"}; fmt.Sprint(got) != fmt.Sprint(want) {
		t.Errorf("messages = %v, want %v", got, want)
	}
}

func toolRecords(results ...string) []ToolRecord {
	recs := make([]ToolRecord, len(results))
	for i, r := range results {
		recs[i] = ToolRecord{
			ToolCall: provider.ToolCall{ID: fmt.Sprintf("srv%d", i), Name: fmt.Sprintf("tool%d", i), Arguments: map[string]any{"n": float64(i)}},
			Result:   r,
		}
	}
	return recs
}

func addToolTurn(t *testing.T, h *History, user, reply string, recs []ToolRecord) {
	t.Helper()
	if err := h.Add("user", user, "m", false); err != nil {
		t.Fatalf("add user: %v", err)
	}
	if err := h.AddAssistantTo(h.ConvID(), reply, EncodeToolRecords(recs)); err != nil {
		t.Fatalf("add assistant: %v", err)
	}
}

func storedIDs(t *testing.T, s *store.Store, convID int64) []int64 {
	t.Helper()
	rows, err := s.ListMessages(convID)
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	ids := make([]int64, len(rows))
	for i, r := range rows {
		ids[i] = r.ID
	}
	return ids
}

func reloaded(t *testing.T, h *History, convID int64) []provider.Message {
	t.Helper()
	other, err := h.NewConversation("m", false)
	if err != nil {
		t.Fatalf("new conversation: %v", err)
	}
	_ = other
	if err := h.Switch(convID); err != nil {
		t.Fatalf("switch back: %v", err)
	}
	return h.Messages()
}

func TestToolTurnReloadsAsCallResultsAndText(t *testing.T) {
	h, s := newTestHistory(t)
	convID, _ := h.NewConversation("m", false)
	addToolTurn(t, h, "save it", "saved", toolRecords("ok one", "ok two"))
	row := storedIDs(t, s, convID)[1]

	msgs := reloaded(t, h, convID)
	if len(msgs) != 5 {
		t.Fatalf("got %d messages, want 5: %+v", len(msgs), msgs)
	}
	id0, id1 := fmt.Sprintf("h%d_0", row), fmt.Sprintf("h%d_1", row)
	if msgs[0].Role != "user" {
		t.Errorf("msgs[0] = %+v", msgs[0])
	}
	calls := msgs[1].ToolCalls
	if msgs[1].Role != "assistant" || msgs[1].Content != "" || len(calls) != 2 || calls[0].ID != id0 || calls[1].ID != id1 {
		t.Errorf("assistant call message = %+v", msgs[1])
	}
	for i, want := range []struct{ id, name, content string }{{id0, "tool0", "ok one"}, {id1, "tool1", "ok two"}} {
		m := msgs[2+i]
		if m.Role != "tool" || m.ToolCallID != want.id || m.ToolName != want.name || m.Content != want.content {
			t.Errorf("tool message %d = %+v", i, m)
		}
	}
	if msgs[4].Role != "assistant" || msgs[4].Content != "saved" || len(msgs[4].ToolCalls) != 0 {
		t.Errorf("final text = %+v", msgs[4])
	}
}

func TestLiveToolTurnMatchesAFreshReload(t *testing.T) {
	h, _ := newTestHistory(t)
	convID, _ := h.NewConversation("m", false)
	addToolTurn(t, h, "q0", "a0", toolRecords("r0", "r1"))
	addToolTurn(t, h, "q1", "", toolRecords("r2"))
	addToolTurn(t, h, "q2", "plain", nil)

	live := h.Messages()
	fresh := reloaded(t, h, convID)
	if !reflect.DeepEqual(live, fresh) {
		t.Fatalf("live and reloaded history differ:\nlive:  %+v\nfresh: %+v", live, fresh)
	}
}

func TestLegacyToolRowStaysOneTextMessage(t *testing.T) {
	h, _ := newTestHistory(t)
	convID, _ := h.NewConversation("m", false)
	addToolTurn(t, h, "q", "answer", toolRecords("", ""))

	msgs := reloaded(t, h, convID)
	if len(msgs) != 2 || msgs[1].Role != "assistant" || msgs[1].Content != "answer" || len(msgs[1].ToolCalls) != 0 {
		t.Fatalf("legacy row expanded: %+v", msgs)
	}
}

func TestToolOnlyTurnEndsWithTheToolMessage(t *testing.T) {
	h, _ := newTestHistory(t)
	convID, _ := h.NewConversation("m", false)
	addToolTurn(t, h, "q", "", toolRecords("done"))

	msgs := reloaded(t, h, convID)
	if len(msgs) != 3 || msgs[2].Role != "tool" {
		t.Fatalf("want user, assistant calls, tool: %+v", msgs)
	}
}

func TestLongToolResultIsBoundedOnARuneBoundary(t *testing.T) {
	h, _ := newTestHistory(t)
	convID, _ := h.NewConversation("m", false)
	long := strings.Repeat("あ", 1000)
	addToolTurn(t, h, "q", "x", toolRecords(long))

	got := reloaded(t, h, convID)[2].Content
	body, marker, found := strings.Cut(got, "\n[truncated in history:")
	if !found {
		t.Fatalf("no truncation marker: %q", got)
	}
	if !utf8.ValidString(body) || len(body) > maxReplayResultBytes {
		t.Errorf("body invalid or too long: %d bytes, valid=%v", len(body), utf8.ValidString(body))
	}
	if want := fmt.Sprintf(" %d of %d bytes omitted]", len(long)-len(body), len(long)); marker != want {
		t.Errorf("marker = %q, want %q", marker, want)
	}
}

func TestEmptyToolResultReadsAsNoOutput(t *testing.T) {
	h, _ := newTestHistory(t)
	convID, _ := h.NewConversation("m", false)
	recs := toolRecords("")
	recs = append(recs, ToolRecord{ToolCall: provider.ToolCall{Name: "bad"}, Error: "boom"})
	addToolTurn(t, h, "q", "x", recs)

	msgs := reloaded(t, h, convID)
	if msgs[2].Content != "(no output)" {
		t.Errorf("tool content = %q", msgs[2].Content)
	}
}

func TestWindowStartsOnAUserAndKeepsResultsWithTheirCalls(t *testing.T) {
	h, _ := newTestHistory(t)
	convID, _ := h.NewConversation("m", false)
	for i := 0; i < 3; i++ {
		addToolTurn(t, h, fmt.Sprintf("q%d", i), "a", toolRecords("r0", "r1"))
	}

	for limit := 1; limit <= 14; limit++ {
		h.max = limit
		msgs := reloaded(t, h, convID)
		if len(msgs) > 0 && msgs[0].Role != "user" {
			t.Fatalf("max=%d: window opens on %q", limit, msgs[0].Role)
		}
		issued := map[string]bool{}
		for _, m := range msgs {
			for _, tc := range m.ToolCalls {
				issued[tc.ID] = true
			}
			if m.Role == "tool" && !issued[m.ToolCallID] {
				t.Fatalf("max=%d: tool result %s has no call in the window", limit, m.ToolCallID)
			}
		}
	}
}

func TestContextDroppedCountsStoredRows(t *testing.T) {
	h, _ := newTestHistory(t)
	convID, _ := h.NewConversation("m", false)
	addToolTurn(t, h, "q0", "a0", toolRecords("r0", "r1"))
	addToolTurn(t, h, "q1", "a1", nil)
	h.max = 3

	got, err := h.ContextDropped(convID)
	if err != nil {
		t.Fatalf("ContextDropped: %v", err)
	}
	if got != 2 {
		t.Fatalf("dropped = %d, want 2 stored rows (user + tool turn)", got)
	}
}

func TestReplayedResultsRememberWhetherALocalModelFetchedThem(t *testing.T) {
	h, _ := newTestHistory(t)
	convID, _ := h.NewConversation("m", false)
	recs := toolRecords("from ollama", "from an older row", "from claude")
	recs[0].Provider = "ollama"
	recs[2].Provider = "anthropic"
	addToolTurn(t, h, "q", "a", recs)

	want := map[string]bool{"from ollama": true, "from an older row": true, "from claude": false}
	for _, msgs := range [][]provider.Message{h.Messages(), reloaded(t, h, convID)} {
		for _, m := range msgs {
			if m.Role != "tool" {
				continue
			}
			if m.LocalOnly != want[m.Content] {
				t.Errorf("%q: LocalOnly = %v, want %v", m.Content, m.LocalOnly, want[m.Content])
			}
		}
	}
}

func TestWithholdLocalResultsBlanksOnlyTheLocalOnes(t *testing.T) {
	msgs := []provider.Message{
		{Role: "user", Content: "q"},
		{Role: "tool", Content: "secret notification text", LocalOnly: true},
		{Role: "tool", Content: "cloud result"},
		{Role: "assistant", Content: "reply"},
	}
	WithholdLocalResults(msgs)

	if msgs[1].Content != withheldResult {
		t.Errorf("local result = %q, want it withheld", msgs[1].Content)
	}
	for _, i := range []int{0, 2, 3} {
		if msgs[i].Content == withheldResult {
			t.Errorf("message %d was withheld but did not come from a local model", i)
		}
	}
}

func TestWithholdingDoesNotTouchTheHistoryItself(t *testing.T) {
	h, _ := newTestHistory(t)
	h.NewConversation("m", false)
	addToolTurn(t, h, "q", "a", toolRecords("kept"))

	WithholdLocalResults(h.Messages())

	for _, m := range h.Messages() {
		if m.Role == "tool" && m.Content != "kept" {
			t.Fatalf("history copy changed to %q", m.Content)
		}
	}
}

func TestDeleteAllResetsPointerWithAnotherConnectionOpen(t *testing.T) {
	h, s := newTestHistory(t)
	chat, err := store.Open(s.Path())
	if err != nil {
		t.Fatalf("open second connection: %v", err)
	}
	defer chat.Close()
	seedExchange(t, h, 1)

	if err := h.DeleteAll(); err != nil {
		t.Fatalf("delete all: %v", err)
	}
	if id := h.ConvID(); id != 0 {
		t.Errorf("current conversation = %d, want none", id)
	}
	if id, err := s.GetCurrentConversationID(); err != nil || id != 0 {
		t.Errorf("stored pointer = %d, %v", id, err)
	}
	if _, err := h.NewConversation("m", false); err != nil {
		t.Errorf("new conversation after delete all: %v", err)
	}
}
