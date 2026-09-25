package cmd

import (
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/tmy7533018/mugen-ai/internal/store"
)

// Desktop state must stay off: its calendar gather execs selfPath(), which here is this test binary.
func sandboxRuntime(t *testing.T) {
	t.Helper()
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)
	t.Setenv("XDG_STATE_HOME", dir)
	t.Setenv("XDG_DATA_HOME", dir)
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	for _, v := range []string{"ANTHROPIC_API_KEY", "OPENAI_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY"} {
		t.Setenv(v, "")
	}
	confDir := filepath.Join(dir, "mugen-ai")
	if err := os.MkdirAll(confDir, 0o700); err != nil {
		t.Fatal(err)
	}
	toml := "[provider.ollama]\nhost = \"http://127.0.0.1:1\"\n\n[context]\ndesktop_state = false\n"
	if err := os.WriteFile(filepath.Join(confDir, "config.toml"), []byte(toml), 0o600); err != nil {
		t.Fatal(err)
	}
}

func withStdin(t *testing.T, input string) {
	t.Helper()
	f, err := os.CreateTemp(t.TempDir(), "stdin")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.WriteString(input); err != nil {
		t.Fatal(err)
	}
	if _, err := f.Seek(0, io.SeekStart); err != nil {
		t.Fatal(err)
	}
	old := os.Stdin
	os.Stdin = f
	t.Cleanup(func() {
		os.Stdin = old
		f.Close()
	})
}

func TestChatSurfacesAnOverlongStdinLineInsteadOfSilentlyStopping(t *testing.T) {
	sandboxRuntime(t)
	withStdin(t, strings.Repeat("x", (4<<20)+10))

	err := runChat(nil, nil)
	if err == nil {
		t.Fatal("runChat() error = nil, want an error for a line past the scan buffer")
	}
	if !strings.Contains(err.Error(), "read stdin") {
		t.Fatalf("err = %v, want it to mention reading stdin", err)
	}
}

func TestChatAcceptsALineTheOldDefaultBufferWouldHaveRejected(t *testing.T) {
	sandboxRuntime(t)
	big := strings.Repeat("x", 200*1024)
	withStdin(t, big+"\nexit\n")

	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	oldStderr := os.Stderr
	os.Stderr = w
	runErr := runChat(nil, nil)
	os.Stderr = oldStderr
	w.Close()
	captured, _ := io.ReadAll(r)

	if runErr != nil {
		t.Fatalf("runChat() error = %v, want nil", runErr)
	}
	// "no model configured" proves the 200 KiB line reached the chat turn, not dropped by the scan.
	if !strings.Contains(string(captured), "no model configured") {
		t.Fatalf("stderr = %q, want the 200 KiB line to have reached the chat turn", captured)
	}
}

func TestChatMarksAReplyThatWasCutOff(t *testing.T) {
	sandboxRuntime(t)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/api/chat" {
			fmt.Fprintln(w, `{"message":{"content":"half an ans"},"done":false}`)
			return
		}
		fmt.Fprint(w, `{"models":[{"name":"stub"}]}`)
	}))
	defer srv.Close()
	toml := "[provider.ollama]\nhost = \"" + srv.URL + "\"\n\n[context]\ndesktop_state = false\n"
	if err := os.WriteFile(filepath.Join(os.Getenv("XDG_CONFIG_HOME"), "mugen-ai", "config.toml"), []byte(toml), 0o600); err != nil {
		t.Fatal(err)
	}
	withStdin(t, "hi\nexit\n")

	if err := runChat(nil, nil); err != nil {
		t.Fatalf("runChat() error = %v", err)
	}

	st, err := store.Open(filepath.Join(os.Getenv("XDG_STATE_HOME"), "mugen-ai", "history.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer st.Close()
	convs, err := st.ListConversations()
	if err != nil || len(convs) != 1 {
		t.Fatalf("conversations = %v, %v; want exactly one", convs, err)
	}
	msgs, err := st.ListMessages(convs[0].ID)
	if err != nil {
		t.Fatal(err)
	}
	last := msgs[len(msgs)-1]
	if last.Role != "assistant" || last.Content != "half an ans\n\n[interrupted]" {
		t.Fatalf("last message = %s %q, want the partial reply marked [interrupted]", last.Role, last.Content)
	}
}
