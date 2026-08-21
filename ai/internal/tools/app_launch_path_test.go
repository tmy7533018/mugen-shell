package tools

import (
	"strings"
	"testing"
)

// The allowlist holds app names, so matching on basename alone let any path whose
// last element collided with an entry through. Prompt injection reaches this.
func TestAppLaunchRejectsPathWithAllowedBasename(t *testing.T) {
	r, _, _ := newTestRegistry(t, []string{"firefox"}, nil)

	for _, cmd := range []string{"/tmp/evil/firefox", "./firefox", "../firefox"} {
		args := map[string]any{"cmd": cmd}
		if rejection := r.rejectAppLaunch(args); rejection == "" {
			t.Errorf("%q was allowed by a basename match", cmd)
		}
	}

	args := map[string]any{"cmd": "firefox"}
	if rejection := r.rejectAppLaunch(args); rejection != "" {
		t.Errorf("the bare allowed name must still pass: %s", rejection)
	}
}

// An allowlist entry that is itself a path keeps working verbatim.
func TestAppLaunchAllowsExactPathEntry(t *testing.T) {
	r, _, _ := newTestRegistry(t, []string{"/opt/thing/bin/thing"}, nil)

	args := map[string]any{"cmd": "/opt/thing/bin/thing"}
	if rejection := r.rejectAppLaunch(args); rejection != "" {
		t.Errorf("exact path entry rejected: %s", rejection)
	}
	if rejection := r.rejectAppLaunch(map[string]any{"cmd": "/tmp/thing"}); rejection == "" {
		t.Error("a different path with the same basename was allowed")
	}
	if rejection := r.rejectAppLaunch(map[string]any{"cmd": "thing"}); !strings.Contains(rejection, "error") {
		t.Error("a bare name must not match a path-only allowlist entry")
	}
}
