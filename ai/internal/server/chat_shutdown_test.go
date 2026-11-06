package server

import (
	"bufio"
	"context"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/tmy7533018/mugen-ai/internal/provider"
)

type waitingProvider struct {
	scriptedProvider
	once    sync.Once
	entered chan struct{}
}

func (p *waitingProvider) Chat(ctx context.Context, _ string, _ []provider.Message,
	_ provider.ChatOptions, _ func(provider.ChatChunk) error) error {
	p.once.Do(func() { close(p.entered) })
	<-ctx.Done()
	return ctx.Err()
}

func TestShutdownEndsATurnInsteadOfWaitingOutTheDeadline(t *testing.T) {
	p := &waitingProvider{entered: make(chan struct{})}
	s, st := newChatServer(t, p)
	hs := s.NewHTTPServer()
	t.Cleanup(func() { hs.Close() })
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	go hs.Serve(ln)

	resp, err := http.Post("http://"+ln.Addr().String()+"/chat", "application/json", strings.NewReader(chatJSON(t, "hello", 0)))
	if err != nil {
		t.Fatalf("POST /chat: %v", err)
	}
	defer resp.Body.Close()
	body := bufio.NewReader(resp.Body)
	if _, err := body.ReadString('\n'); err != nil {
		t.Fatalf("stream did not open: %v", err)
	}
	<-p.entered

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	start := time.Now()
	if err := hs.Shutdown(ctx); err != nil {
		t.Fatalf("Shutdown during a turn: %v", err)
	}
	if took := time.Since(start); took > time.Second {
		t.Fatalf("Shutdown took %v during a turn", took)
	}

	rest, _ := io.ReadAll(body)
	if !strings.Contains(string(rest), `"error"`) {
		t.Errorf("the client was not told the turn ended: %q", rest)
	}
	convs, err := st.ListConversations()
	if err != nil || len(convs) != 1 {
		t.Fatalf("conversations = %d (%v), want 1", len(convs), err)
	}
	if msgs, err := st.ListMessages(convs[0].ID); err != nil || len(msgs) != 0 {
		t.Errorf("messages = %d (%v), want the unanswered message rolled back", len(msgs), err)
	}
}

func TestChatRunsNoFurtherToolAfterTheClientLeft(t *testing.T) {
	calls := []provider.ToolCall{
		{ID: "1", Name: "memory_delete", Arguments: map[string]any{"id": float64(1)}},
		{ID: "2", Name: "memory_save", Arguments: map[string]any{"content": "written after the client left"}},
	}
	s, st := newChatServer(t, &turnProvider{rounds: [][]provider.ToolCall{calls}})
	s.tools.AttachMemory(st)
	if _, err := st.AddMemory("x"); err != nil {
		t.Fatal(err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() {
		for ctx.Err() == nil {
			s.confirms.mu.Lock()
			n := len(s.confirms.pending)
			s.confirms.mu.Unlock()
			if n > 0 {
				cancel()
				return
			}
			time.Sleep(5 * time.Millisecond)
		}
	}()
	req := httptest.NewRequest(http.MethodPost, "/chat", strings.NewReader(chatJSON(t, "don't forget I like tea, and tidy up", 0))).WithContext(ctx)
	req.Header.Set("Content-Type", "application/json")
	s.handleChat(httptest.NewRecorder(), req)

	mems, err := st.ListMemories()
	if err != nil {
		t.Fatal(err)
	}
	if len(mems) != 1 {
		t.Errorf("memories = %d, want the second tool not to have run", len(mems))
	}
}
