package server

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGuardMiddleware(t *testing.T) {
	handler := guardMiddleware(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	tests := []struct {
		name   string
		method string
		host   string
		origin string
		want   int
	}{
		{"shell curl: loopback host, no origin", "POST", "127.0.0.1:11435", "", http.StatusOK},
		{"localhost host, no origin", "POST", "localhost:11435", "", http.StatusOK},
		{"loopback origin allowed", "POST", "127.0.0.1:11435", "http://127.0.0.1:11435", http.StatusOK},
		{"browser cross-site origin blocked", "POST", "127.0.0.1:11435", "https://evil.example", http.StatusForbidden},
		{"dns-rebinding non-loopback host blocked", "POST", "attacker.example", "", http.StatusForbidden},
		{"preflight from loopback", "OPTIONS", "127.0.0.1:11435", "", http.StatusNoContent},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(tc.method, "http://"+tc.host+"/health", nil)
			req.Host = tc.host
			if tc.origin != "" {
				req.Header.Set("Origin", tc.origin)
			}
			rec := httptest.NewRecorder()
			handler.ServeHTTP(rec, req)
			if rec.Code != tc.want {
				t.Fatalf("host=%q origin=%q: got %d, want %d", tc.host, tc.origin, rec.Code, tc.want)
			}
		})
	}
}
