// Package apps reads XDG desktop entries so the tools registry can resolve
// a basename ("zen-bin") to the absolute Exec path ("/opt/zen-browser-bin/
// zen-bin"). Without this, app_launch silently fires `exec zen-bin` via
// Hyprland for binaries that aren't on $PATH and the user sees "launched"
// while nothing actually opens.
package apps

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
)

// App is a parsed .desktop entry kept around so callers can do alias-style
// resolution (e.g. user says "discord" but the underlying binary is
// "flatpak" — the display name lets us still find the right Exec).
type App struct {
	Binary  string // basename of the first Exec token
	Display string // user-facing "Name=" value
	Exec    string // full Exec line, placeholders stripped
}

// Resolver caches a basename → absolute-exec map built from .desktop
// entries discovered under XDG data dirs, plus the parsed App list so we
// can fall back to display-name matching when the typed cmd doesn't line
// up with the underlying binary (Flatpak / AppImage launchers).
type Resolver struct {
	byBin map[string]string
	apps  []App
}

// Load walks all XDG application dirs once and returns a populated
// Resolver. Reload by calling Load again — there's no live watcher.
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

// Resolve returns the absolute Exec path (with placeholders stripped) for
// a binary basename, or "" if no .desktop entry advertises it. Callers
// should fall through to the original cmd when this returns empty.
func (r *Resolver) Resolve(basename string) string {
	if r == nil {
		return ""
	}
	return r.byBin[basename]
}

// FindByDisplay finds an installed app whose display name matches `name`
// case-insensitively. Used as a fallback when the user-typed command
// doesn't match any binary basename (the common Flatpak case where the
// "binary" is `flatpak` for every app). Returns the first exact display
// match, then falls back to a single substring match if exactly one app
// contains the needle in its name.
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
			// We only care about the [Desktop Entry] group; sub-groups
			// (Actions etc.) carry their own Exec lines we shouldn't pick up.
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

// stripPlaceholders drops field codes defined by the XDG desktop-entry spec
// (%u %U %f %F %i %c %k %d %D %n %N %v %m) and Flatpak's file-forwarding
// sentinels (@@, @@u). The sentinels are inert when no payload is attached
// but some launchers treat them as unknown args; safer to drop them.
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
