// Package apps reads XDG desktop entries so a basename ("zen-bin") resolves
// to its absolute Exec path. Without this, app_launch reports success for
// binaries that aren't on $PATH while nothing actually opens.
package apps

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
)

// App is a parsed .desktop entry. Display is kept so callers can resolve by
// name when the binary is a launcher shared by many apps (e.g. "flatpak").
type App struct {
	Binary  string // basename of the first Exec token
	Display string // user-facing "Name=" value
	Exec    string // full Exec line, placeholders stripped
}

// Resolver caches a basename → absolute-exec map built from the .desktop
// entries under the XDG data dirs.
type Resolver struct {
	byBin map[string]string
	apps  []App
}

// Load scans the XDG application dirs once; there is no live watcher, so
// call it again to pick up newly installed apps.
func Load() *Resolver {
	r := &Resolver{byBin: map[string]string{}}
	for _, dir := range desktopDirs() {
		files, _ := filepath.Glob(filepath.Join(dir, "*.desktop"))
		for _, f := range files {
			app, ok := parseDesktop(f)
			if !ok {
				continue
			}
			// First win: respect the search order (user > system).
			if _, seen := r.byBin[app.Binary]; !seen {
				r.byBin[app.Binary] = app.Exec
			}
			r.apps = append(r.apps, app)
		}
	}
	return r
}

// Resolve returns the absolute Exec path for a binary basename, or "" if no
// .desktop entry advertises it; callers then fall through to the raw cmd.
func (r *Resolver) Resolve(basename string) string {
	if r == nil {
		return ""
	}
	return r.byBin[basename]
}

// FindByDisplay matches an app by display name, case-insensitively: exact
// first, then a substring match only when exactly one app contains the
// needle. Fallback for when the typed command matches no binary basename.
func (r *Resolver) FindByDisplay(name string) (App, bool) {
	if r == nil {
		return App{}, false
	}
	needle := strings.ToLower(strings.TrimSpace(name))
	if needle == "" {
		return App{}, false
	}
	var subMatches []App
	for _, a := range r.apps {
		lname := strings.ToLower(a.Display)
		if lname == needle {
			return a, true
		}
		if strings.Contains(lname, needle) {
			subMatches = append(subMatches, a)
		}
	}
	if len(subMatches) == 1 {
		return subMatches[0], true
	}
	return App{}, false
}

func parseDesktop(path string) (App, bool) {
	f, err := os.Open(path)
	if err != nil {
		return App{}, false
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	inMain := false
	var exec, name string
	var noDisplay, hidden bool
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.HasPrefix(line, "[") {
			// Sub-groups (Actions etc.) carry their own Exec lines that
			// must not be picked up.
			if line == "[Desktop Entry]" {
				inMain = true
			} else if inMain {
				break
			}
			continue
		}
		if !inMain {
			continue
		}
		switch {
		case strings.HasPrefix(line, "Exec=") && exec == "":
			exec = strings.TrimPrefix(line, "Exec=")
		case strings.HasPrefix(line, "Name=") && name == "":
			name = strings.TrimPrefix(line, "Name=")
		case line == "NoDisplay=true":
			noDisplay = true
		case line == "Hidden=true":
			hidden = true
		}
	}
	if exec == "" || noDisplay || hidden {
		return App{}, false
	}
	tokens := strings.Fields(exec)
	if len(tokens) == 0 {
		return App{}, false
	}
	binary := filepath.Base(tokens[0])
	clean := stripPlaceholders(tokens)
	if clean == "" {
		return App{}, false
	}
	if name == "" {
		name = binary
	}
	return App{Binary: binary, Display: name, Exec: clean}, true
}

// Drops XDG field codes (%u, %F, ...) and Flatpak's file-forwarding
// sentinels (@@, @@u) — the latter are inert with no payload attached, but
// some launchers reject them as unknown args.
func stripPlaceholders(tokens []string) string {
	out := make([]string, 0, len(tokens))
	for _, t := range tokens {
		if len(t) == 2 && t[0] == '%' {
			continue
		}
		if t == "@@" || t == "@@u" {
			continue
		}
		out = append(out, t)
	}
	return strings.Join(out, " ")
}

func desktopDirs() []string {
	var dirs []string
	home, _ := os.UserHomeDir()
	if xdgData := os.Getenv("XDG_DATA_HOME"); xdgData != "" {
		dirs = append(dirs, filepath.Join(xdgData, "applications"))
	} else if home != "" {
		dirs = append(dirs, filepath.Join(home, ".local/share/applications"))
	}
	if xdgDataDirs := os.Getenv("XDG_DATA_DIRS"); xdgDataDirs != "" {
		for _, d := range strings.Split(xdgDataDirs, ":") {
			if d == "" {
				continue
			}
			dirs = append(dirs, filepath.Join(d, "applications"))
		}
	} else {
		dirs = append(dirs,
			"/usr/local/share/applications",
			"/usr/share/applications",
			// NixOS has no /usr/share; cover its profile share dirs too.
			"/run/current-system/sw/share/applications",
		)
		if home != "" {
			dirs = append(dirs, filepath.Join(home, ".nix-profile/share/applications"))
		}
		if u := os.Getenv("USER"); u != "" {
			dirs = append(dirs, filepath.Join("/etc/profiles/per-user", u, "share/applications"))
		}
	}
	return dirs
}
