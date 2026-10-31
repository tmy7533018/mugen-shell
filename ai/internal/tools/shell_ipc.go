package tools

import (
	"context"
	"strconv"
	"strings"
	"time"
)

// Addressing by pid is what makes this work headless: `qs ipc` otherwise matches on the display.
func (r *Registry) shellIPC(ctx context.Context, pid int, target, fn string) (string, bool) {
	args := []string{"-c", r.qsConfig, "ipc", "call", target, fn}
	if pid > 0 {
		args = []string{"ipc", "--pid", strconv.Itoa(pid), "call", target, fn}
	}
	out, err := r.run(ctx, "qs", args)
	return out, err == nil && out != ""
}

const (
	confirmTimeout  = 10 * time.Second
	confirmInterval = 400 * time.Millisecond
)

func (r *Registry) confirm(ctx context.Context, t *Tool, want string) (last string, matched bool) {
	pid := r.resolveQsPID(ctx)
	deadline := time.Now().Add(confirmTimeout)
	for {
		if got, ok := r.shellIPC(ctx, pid, t.target, t.confirmFn); ok {
			if got == want {
				return got, true
			}
			last = got
		}
		if time.Now().After(deadline) {
			return last, false
		}
		select {
		case <-ctx.Done():
			return last, false
		case <-time.After(confirmInterval):
		}
	}
}

// `qs list --all` is used because, unlike `qs ipc`, it works with no display.
func (r *Registry) resolveQsPID(ctx context.Context) int {
	out, err := r.run(ctx, "qs", []string{"list", "--all"})
	if err != nil {
		return 0
	}
	return parseInstancePID(out, r.qsConfig)
}

func parseInstancePID(listOutput, qsConfig string) int {
	suffix := "/" + qsConfig + "/shell.qml"
	pid := 0
	for _, line := range strings.Split(listOutput, "\n") {
		line = strings.TrimSpace(line)
		if v, ok := strings.CutPrefix(line, "Process ID:"); ok {
			pid, _ = strconv.Atoi(strings.TrimSpace(v))
		} else if v, ok := strings.CutPrefix(line, "Config path:"); ok {
			if strings.HasSuffix(strings.TrimSpace(v), suffix) {
				return pid
			}
		}
	}
	return 0
}
