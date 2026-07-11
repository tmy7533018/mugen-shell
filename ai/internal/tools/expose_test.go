package tools

import "testing"

func exposedNames(ts []Tool) map[string]bool {
	out := map[string]bool{}
	for _, t := range ts {
		out[t.Name] = true
	}
	return out
}

func TestExposedToolsReadonlyOnly(t *testing.T) {
	r := New("", "", nil, nil, NewAuditor(""))
	got := r.ExposedTools(true, nil)
	if len(got) == 0 {
		t.Fatal("expected read-only tools to be exposed")
	}
	for _, tool := range got {
		if !tool.readonly {
			t.Errorf("write tool %q leaked through readonly-only exposure", tool.Name)
		}
	}
	names := exposedNames(got)
	for _, want := range []string{"audio_get_volume", "wallpaper_list", "timer_get"} {
		if !names[want] {
			t.Errorf("expected read-only tool %q to be exposed", want)
		}
	}
	for _, forbidden := range []string{"audio_set_volume", "app_launch", "notification_clear_all"} {
		if names[forbidden] {
			t.Errorf("write tool %q must not be exposed by default", forbidden)
		}
	}
}

func TestExposedToolsCategoriesAddWrites(t *testing.T) {
	r := New("", "", nil, nil, NewAuditor(""))
	got := r.ExposedTools(false, []string{"theme"})
	names := exposedNames(got)
	for _, want := range []string{"theme_set", "theme_toggle", "theme_get"} {
		if !names[want] {
			t.Errorf("expected %q from the theme category", want)
		}
	}
	if len(got) != 3 {
		t.Errorf("expected exactly the 3 theme tools, got %d: %v", len(got), names)
	}
}

func TestExposedToolsExcludesMCPTools(t *testing.T) {
	r := New("", "", nil, nil, NewAuditor(""))
	r.tools = append(r.tools, Tool{Name: "somesrv__read_thing", kind: "mcp", readonly: true})
	names := exposedNames(r.ExposedTools(true, []string{"somesrv"}))
	if names["somesrv__read_thing"] {
		t.Error("MCP-sourced tools must never be re-exported")
	}
}

func TestExposedToolsRespectsDisabledCategories(t *testing.T) {
	r := New("", "", nil, []string{"theme"}, NewAuditor(""))
	names := exposedNames(r.ExposedTools(true, []string{"theme"}))
	if names["theme_get"] || names["theme_set"] {
		t.Error("disabled category must stay unexposed even when explicitly listed")
	}
}
