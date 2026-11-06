package tools

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestWeatherRefusesAnOversizedResponse(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = io.WriteString(w, `{"pad":"`+strings.Repeat("x", 2<<20)+`"}`)
	}))
	defer ts.Close()

	var out map[string]any
	if err := testWeatherAPI("", ts.URL, ts.URL).getJSON(context.Background(), ts.URL, &out); err == nil {
		t.Error("decoded a response larger than the limit")
	}
}
