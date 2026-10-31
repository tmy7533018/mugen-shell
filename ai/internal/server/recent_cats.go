package server

import (
	"sort"
	"sync"
	"time"
)

// Unioned into every turn's selection, so a keyword-less follow-up keeps the tools it means.
type recentCats struct {
	mu        sync.Mutex
	m         map[int64]map[string]time.Time
	lastSweep time.Time
}

const recentCatTTL = 15 * time.Minute

func newRecentCats() *recentCats {
	return &recentCats{m: map[int64]map[string]time.Time{}}
}

func (rc *recentCats) note(conv int64, cat string) {
	rc.mu.Lock()
	defer rc.mu.Unlock()
	rc.sweepLocked()
	if rc.m[conv] == nil {
		rc.m[conv] = map[string]time.Time{}
	}
	rc.m[conv][cat] = time.Now()
}

// get() only prunes the conversation it is queried with, so an abandoned one would leak.
func (rc *recentCats) sweepLocked() {
	now := time.Now()
	if now.Sub(rc.lastSweep) < recentCatTTL {
		return
	}
	rc.lastSweep = now
	cutoff := now.Add(-recentCatTTL)
	for conv, cats := range rc.m {
		for cat, at := range cats {
			if at.Before(cutoff) {
				delete(cats, cat)
			}
		}
		if len(cats) == 0 {
			delete(rc.m, conv)
		}
	}
}

func (rc *recentCats) get(conv int64) []string {
	rc.mu.Lock()
	defer rc.mu.Unlock()
	cutoff := time.Now().Add(-recentCatTTL)
	var out []string
	for cat, at := range rc.m[conv] {
		if at.Before(cutoff) {
			delete(rc.m[conv], cat)
			continue
		}
		out = append(out, cat)
	}
	if len(rc.m[conv]) == 0 {
		delete(rc.m, conv)
	}
	sort.Strings(out)
	return out
}
