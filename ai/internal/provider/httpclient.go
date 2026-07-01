package provider

import (
	"net/http"
	"time"
)

// streamingHTTPClient returns a client with no overall timeout so a long
// thinking or multi-tool turn can stream past two minutes. A stalled
// connection is still bounded by the response-header timeout, and the caller's
// request context cancels the whole exchange on client disconnect.
func streamingHTTPClient() *http.Client {
	t := http.DefaultTransport.(*http.Transport).Clone()
	t.ResponseHeaderTimeout = 120 * time.Second
	return &http.Client{Transport: t}
}
