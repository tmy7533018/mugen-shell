package mcp

import (
	"context"
	"strings"
	"testing"
)

func TestConnectRefusesServerNamesProvidersRejectOrCategoriesMisread(t *testing.T) {
	names := []string{"my.srv", "1password", "-srv", "my__srv", "srv_", "カレンダー", "my srv", ""}
	for _, name := range names {
		mgr := Connect(context.Background(), map[string]ServerConfig{name: {URL: "http://127.0.0.1:1"}})
		statuses := mgr.Statuses()
		if len(statuses) != 1 {
			t.Errorf("name %q: got %d statuses, want 1", name, len(statuses))
			mgr.Close()
			continue
		}
		st := statuses[0]
		if st.Connected {
			t.Errorf("name %q: got Connected=true, want false", name)
		}
		if !strings.Contains(st.Error, "invalid server name") {
			t.Errorf("name %q: got Error=%q, want it to contain %q", name, st.Error, "invalid server name")
		}
		if len(mgr.Clients()) != 0 {
			t.Errorf("name %q: got %d clients, want 0", name, len(mgr.Clients()))
		}
		mgr.Close()
	}
}

func TestValidServerNameAcceptsProviderSafeNames(t *testing.T) {
	names := []string{"memory", "my-server", "My_Srv", "a1", "github"}
	for _, name := range names {
		if !ValidServerName(name) {
			t.Errorf("ValidServerName(%q) = false, want true", name)
		}
	}
}
