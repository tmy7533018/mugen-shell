package hypr

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

func TestFocusMatchesAClassWrappedInTheEntryNameOnlyAtAWordStart(t *testing.T) {
	for _, c := range []struct {
		entry, class string
		want         bool
	}{
		{"org.mozilla.firefox", "firefox", true},
		{"google-chrome-stable", "google-chrome", true},
		{"code-oss", "code", true},
		{"code", "com.microsoft.VSCode", true},
		{"com.obsproject.Studio", "obs", true},
		{"com.heroicgameslauncher.hgl", "heroic", true},
		{"steam", "st", false},
		{"thunderbird", "bird", false},
	} {
		t.Run(c.entry+"/"+c.class, func(t *testing.T) {
			hyprStubs(t, `[{"address":"0xabc","class":"`+c.class+`","initialClass":"`+c.class+`"}]`)
			matched, err := Focus(context.Background(), c.entry)
			if err != nil || matched != c.want {
				t.Errorf("Focus = (%v, %v), want %v", matched, err, c.want)
			}
		})
	}
}

func TestFocusOrLaunchReportsAnEntryThatDoesNotExist(t *testing.T) {
	hyprStubs(t, `[]`)
	dir := filepath.Dir(firstOnPath(t, "hyprctl"))
	stubBin(t, dir, "gtk-launch", "exit 2")

	if _, err := FocusOrLaunch(context.Background(), "no-such-app"); err == nil {
		t.Error("a failed gtk-launch was reported as success")
	}
}

func TestFocusOrLaunchDoesNotWaitForASlowLauncher(t *testing.T) {
	sleep, err := exec.LookPath("sleep")
	if err != nil {
		t.Fatal(err)
	}
	hyprStubs(t, `[]`)
	dir := filepath.Dir(firstOnPath(t, "hyprctl"))
	stubBin(t, dir, "gtk-launch", sleep+" 5")

	start := time.Now()
	if _, err := FocusOrLaunch(context.Background(), "slow-app"); err != nil {
		t.Errorf("a launcher that is still running was reported as failed: %v", err)
	}
	if took := time.Since(start); took > 2*time.Second+time.Second {
		t.Errorf("took %v", took)
	}
}

func firstOnPath(t *testing.T, name string) string {
	t.Helper()
	for _, dir := range filepath.SplitList(os.Getenv("PATH")) {
		p := filepath.Join(dir, name)
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	t.Fatalf("%s is not on PATH", name)
	return ""
}
