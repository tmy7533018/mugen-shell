package provider

import (
	"net/http"
	"time"
)

// No overall timeout, so a long thinking or multi-tool turn can stream past
// two minutes. A stall is still bounded by the response-header timeout, and
// the request context cancels the exchange on client disconnect.
func streamingHTTPClient() *http.Client {
	t := http.DefaultTransport.(*http.Transport).Clone()
	t.ResponseHeaderTimeout = 120 * time.Second
	return &http.Client{Transport: t}
}
