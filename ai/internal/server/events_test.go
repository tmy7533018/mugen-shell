package server

import (
	"bufio"
	"context"
	"net"
	"net/http"
	"strings"
	"testing"
	"time"
)

func TestShutdownEndsOpenEventStreams(t *testing.T) {
	s, _ := newChatServer(t, &scriptedProvider{})
	hs := s.NewHTTPServer()
	t.Cleanup(func() { hs.Close() })
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	go hs.Serve(ln)

	resp, err := http.Get("http://" + ln.Addr().String() + "/events")
	if err != nil {
		t.Fatalf("GET /events: %v", err)
	}
	defer resp.Body.Close()
	if line, err := bufio.NewReader(resp.Body).ReadString('\n'); err != nil || !strings.HasPrefix(line, ": connected") {
		t.Fatalf("stream did not open: %q, %v", line, err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	start := time.Now()
	if err := hs.Shutdown(ctx); err != nil {
		t.Fatalf("Shutdown with an open /events stream: %v", err)
	}
	if took := time.Since(start); took > time.Second {
		t.Fatalf("Shutdown took %v with an open /events stream", took)
	}
}

func TestSubscribeAfterCloseAllGetsAnEndedStream(t *testing.T) {
	b := newEventBus()
	b.closeAll()
	ch := b.subscribe()
	select {
	case _, ok := <-ch:
		if ok {
			t.Fatal("a stream opened after closeAll received an event")
		}
	case <-time.After(time.Second):
		t.Fatal("a stream opened after closeAll stayed open")
	}
	b.unsubscribe(ch)
}
