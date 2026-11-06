package provider

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestOllamaHostTrailingSlashDoesNotDoubleThePath(t *testing.T) {
	var path string
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path = r.URL.Path
		_, _ = io.WriteString(w, `{"models":[]}`)
	}))
	defer ts.Close()

	if _, err := NewOllama(ts.URL+"/", 0, "").Models(context.Background()); err != nil {
		t.Fatal(err)
	}
	if path != "/api/tags" {
		t.Errorf("requested %q, want /api/tags", path)
	}
}
