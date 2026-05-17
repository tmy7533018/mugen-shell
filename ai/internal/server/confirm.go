package server

import (
	"crypto/rand"
	"encoding/hex"
	"sync"
	"time"
)

// confirmTimeout bounds how long a chat turn blocks waiting for the user to
// answer a tool-approval prompt. On expiry the action is treated as denied:
// an unattended prompt must never leave the request hung or quietly proceed.
const confirmTimeout = 2 * time.Minute

// confirmRegistry tracks the tool-approval prompts currently in flight.
// handleChat registers one before it streams a tool_confirm event, then
// blocks on the returned channel; POST /chat/confirm resolves it by id.
// Each id is single-use and unique per request, so two open chat windows
// never cross their prompts.
type confirmRegistry struct {
	mu      sync.Mutex
	pending map[string]chan bool
}

func newConfirmRegistry() *confirmRegistry {
	return &confirmRegistry{pending: map[string]chan bool{}}
}

// register mints a fresh id and a buffered channel for its answer. The
// buffer is what lets resolve deliver an answer even if the chat turn has
// already stopped waiting.
func (c *confirmRegistry) register() (string, chan bool) {
	id := randomID()
	ch := make(chan bool, 1)
	c.mu.Lock()
	c.pending[id] = ch
	c.mu.Unlock()
	return id, ch
}

// resolve delivers the user's answer to the waiting chat turn. It reports
// false when the id is unknown — already answered, expired, or never issued.
func (c *confirmRegistry) resolve(id string, approved bool) bool {
	c.mu.Lock()
	ch, ok := c.pending[id]
	if ok {
		delete(c.pending, id)
	}
	c.mu.Unlock()
	if !ok {
		return false
	}
	ch <- approved // buffered: never blocks
	return true
}

// discard drops an id whose chat turn has stopped waiting (answered, timed
// out, or the connection dropped) so a late POST can't resolve a stale id.
func (c *confirmRegistry) discard(id string) {
	c.mu.Lock()
	delete(c.pending, id)
	c.mu.Unlock()
}

func randomID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	return hex.EncodeToString(b[:])
}
