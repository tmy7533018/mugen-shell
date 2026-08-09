package provider

import (
	"net/http"
	"time"
)

// No overall timeout so a long thinking or multi-tool turn can stream past two minutes.
func streamingHTTPClient() *http.Client {
	t := http.DefaultTransport.(*http.Transport).Clone()
	t.ResponseHeaderTimeout = 120 * time.Second
	return &http.Client{Transport: t}
}
