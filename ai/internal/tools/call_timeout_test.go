package tools

import (
	"context"
	"testing"
	"time"
)

// Call holds the registry lock across execution, so a tool that never returns
// used to block every other conversation's tools too.
func TestCallGivesUpOnAWedgedTool(t *testing.T) {
	r, _, _ := newTestRegistry(t, nil, nil)
	r.callTimeout = 150 * time.Millisecond
	r.run = func(ctx context.Context, _ string, _ []string) (string, error) {
		<-ctx.Done()
		return "", ctx.Err()
	}

	done := make(chan struct{})
	go func() {
		r.Call(context.Background(), "audio_set_volume", map[string]any{"volume": 30})
		close(done)
	}()

	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("Call never returned, so the registry lock would stay held")
	}
}
