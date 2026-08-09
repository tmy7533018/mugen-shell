package server

import (
	"crypto/rand"
	"encoding/hex"
	"sync"
	"time"
)

// On expiry the action is denied: an unattended prompt must never hang or quietly proceed.
const confirmTimeout = 2 * time.Minute

// Ids are single-use, so two open chat windows never cross their confirmation prompts.
type confirmRegistry struct {
	mu      sync.Mutex
	pending map[string]chan bool
}

func newConfirmRegistry() *confirmRegistry {
	return &confirmRegistry{pending: map[string]chan bool{}}
}

// The channel is buffered so resolve can deliver even after the turn stopped waiting.
func (c *confirmRegistry) register() (string, chan bool) {
	id := randomID()
	ch := make(chan bool, 1)
	c.mu.Lock()
	c.pending[id] = ch
	c.mu.Unlock()
	return id, ch
}

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
	ch <- approved
	return true
}

// Drops an id whose turn stopped waiting, so a late POST can't resolve a stale prompt.
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
