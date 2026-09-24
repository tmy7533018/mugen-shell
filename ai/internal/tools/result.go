package tools

import (
	"fmt"
	"strings"
	"unicode/utf8"
)

// MaxLLMResultBytes bounds a tool result before it reaches the model.
// Call's other callers, the MCP expose bridge and /tools/call, get the result unbounded.
const MaxLLMResultBytes = 32 << 10

// ForLLM cuts s to MaxLLMResultBytes at a rune boundary and appends an exact-count
// marker, so one runaway tool result can't blow the model's context budget.
func ForLLM(s string) string {
	if len(s) <= MaxLLMResultBytes {
		return s
	}
	n := MaxLLMResultBytes
	// Bounded so invalid UTF-8 can't back off all the way to n == 0.
	for i := 0; i < utf8.UTFMax-1 && n > 0 && !utf8.RuneStart(s[n]); i++ {
		n--
	}
	if !utf8.RuneStart(s[n]) {
		n = MaxLLMResultBytes
	}
	return s[:n] + fmt.Sprintf("\n[truncated: %d of %d bytes omitted]", len(s)-n, len(s))
}

// ResultPayload turns a tool call's outcome into what the model and the client see, bounded.
// Shared by server.go and cmd/chat.go so the SSE tool_result and provider message match.
func ResultPayload(result string, callErr error) string {
	payload := result
	if callErr != nil {
		payload = "error: " + callErr.Error()
		if result != "" && !strings.Contains(callErr.Error(), "(output: "+result+")") {
			payload += " (output: " + result + ")"
		}
	}
	return ForLLM(payload)
}
