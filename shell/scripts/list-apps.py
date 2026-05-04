#!/usr/bin/env python3
"""Collect installed desktop applications and resolve icons using GTK/GIO.
Outputs JSON compatible with the previous shell implementation.
"""

import hashlib
import json
import os
import re
import sys
import traceback
import warnings
from typing import Optional

try:
    import gi

    gi.require_version("Gio", "2.0")
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gio, Gtk
    from gi import PyGIDeprecationWarning
except Exception:
    traceback.print_exc()
    print("[]")
    sys.exit(1)

warnings.filterwarnings("ignore", category=PyGIDeprecationWarning)

CACHE_DIR = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.join(os.path.expanduser("~"), ".cache")),
    "mugen-shell"
)
CACHE_JSON = os.path.join(CACHE_DIR, "apps_v2.json")
CACHE_SIG = os.path.join(CACHE_DIR, "apps_v2.sha256")


def ensure_cache_dir() -> None:
    os.makedirs(CACHE_DIR, exist_ok=True)


def compute_signature(apps: list) -> str:
    lines = []
    for app in apps:
        filename = app.get_filename()
        if not filename:
            continue
        try:
            mtime = os.path.getmtime(filename)
        except OSError:
            continue
        lines.append(f"{mtime}:{filename}")
    lines.sort()
    data = "\n".join(lines).encode("utf-8")
    return hashlib.sha256(data).hexdigest()


def load_from_cache(signature: str) -> Optional[str]:
    if not os.path.exists(CACHE_JSON) or not os.path.exists(CACHE_SIG):
        return None
    try:
        with open(CACHE_SIG, "r", encoding="utf-8") as f:
            cached_sig = f.read().strip()
        if cached_sig != signature:
            return None
        with open(CACHE_JSON, "r", encoding="utf-8") as f:
            return f.read()
    except OSError:
        return None


def save_cache(signature: str, json_data: str) -> None:
    try:
        with open(CACHE_JSON, "w", encoding="utf-8") as f:
            f.write(json_data)
        with open(CACHE_SIG, "w", encoding="utf-8") as f:
            f.write(signature)
    except OSError:
        pass


def sanitize_exec(command: str) -> str:
    if not command:
        return ""
    cleaned = re.sub(r"%[FfuUdDnNickvm]", "", command)
    cleaned = re.sub(r"@@[uU]?", "", cleaned)
    return " ".join(cleaned.split()).strip()


def read_desktop_file_icon(desktop_file_path: str) -> str:
    try:
        with open(desktop_file_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("Icon="):
                    return line[5:].strip()
    except Exception:
        pass
    return ""


def read_desktop_file_exec(desktop_file_path: str) -> Optional[str]:
    try:
        with open(desktop_file_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("Exec="):
                    return line[5:].strip().split()[0]
    except Exception:
        pass
    return None


def read_desktop_file_wm_class(desktop_file_path: str) -> str:
    try:
        with open(desktop_file_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("StartupWMClass="):
                    return line[15:].strip()
    except Exception:
        pass
    return ""


def read_desktop_file_keywords(desktop_file_path: str) -> str:
    try:
        with open(desktop_file_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("Keywords="):
                    return line[9:].strip()
    except Exception:
        pass
    return ""


def extract_steam_app_id(exec_cmd: str) -> str:
    match = re.search(r'steam://rungameid/(\d+)', exec_cmd)
    if match:
        return match.group(1)
    return ""


def is_temporary_path(path: str) -> bool:
    return "/tmp/.mount_" in path or path.startswith("/tmp/")


def normalize_icon_name(icon_name: str) -> str:
    return re.sub(r"\.(png|svg|xpm)$", "", icon_name, flags=re.IGNORECASE)


def build_theme_icon_paths(base_name: str, theme_name: str, home: str) -> list[str]:
    paths = []

    user_base = os.path.join(home, ".local/share/icons", theme_name)
    sizes = ["scalable", "512x512", "256x256", "128x128", "96x96", "64x64", "48x48", "32x32"]
    for size in sizes:
        if size == "scalable":
            paths.extend([
                os.path.join(user_base, size, "apps", base_name + ".svg"),
                os.path.join(user_base, size, "apps", base_name + ".png"),
            ])
        else:
            paths.append(os.path.join(user_base, size, "apps", base_name + ".png"))

    system_base = os.path.join("/usr/share/icons", theme_name)
    for size in sizes:
        if size == "scalable":
            paths.extend([
                os.path.join(system_base, size, "apps", base_name + ".svg"),
                os.path.join(system_base, size, "apps", base_name + ".png"),
            ])
        else:
            paths.append(os.path.join(system_base, size, "apps", base_name + ".png"))

    return paths


def build_beautyline_icon_paths(base_name: str) -> list[str]:
    """BeautyLine uses apps/scalable/ instead of scalable/apps/"""
    paths = []
    base = "/usr/share/icons/BeautyLine"

    paths.extend([
        os.path.join(base, "apps/scalable", base_name + ".svg"),
        os.path.join(base, "apps/scalable", base_name + ".png"),
    ])

    return paths


def build_hicolor_icon_paths(base_name: str, home: str) -> list[str]:
    paths = []

    user_paths = [
        os.path.join(home, ".local/share/icons/hicolor/scalable/apps", base_name + ".svg"),
        os.path.join(home, ".local/share/icons/hicolor/48x48/apps", base_name + ".png"),
        os.path.join(home, ".local/share/pixmaps", base_name + ".png"),
        os.path.join(home, ".local/share/pixmaps", base_name + ".svg"),
    ]
    paths.extend(user_paths)

    system_sizes = ["scalable", "512x512", "256x256", "128x128", "96x96", "64x64", "48x48", "32x32"]
    for size in system_sizes:
        if size == "scalable":
            paths.extend([
                os.path.join("/usr/share/icons/hicolor", size, "apps", base_name + ".svg"),
                os.path.join("/usr/share/icons/hicolor", size, "apps", base_name + ".png"),
            ])
        else:
            paths.append(os.path.join("/usr/share/icons/hicolor", size, "apps", base_name + ".png"))

    paths.extend([
        os.path.join("/usr/share/pixmaps", base_name + ".png"),
        os.path.join("/usr/share/pixmaps", base_name + ".svg"),
    ])

    return paths


def find_icon_in_paths(search_paths: list[str]) -> str:
    found_temp_path = ""

    for path in search_paths:
        if not os.path.exists(path):
            continue

        if not is_temporary_path(path):
            return path

        if not found_temp_path:
            found_temp_path = path

    return found_temp_path


def _build_search_paths(
    icon_name: str,
    base_name: str,
    desktop_file_path: str,
    theme_name: str,
    home: str
) -> list[str]:
    search_paths = []

    if theme_name and theme_name != "hicolor":
        search_paths.extend(build_theme_icon_paths(base_name, theme_name, home))

    fallback_themes = ["BeautyLine", "Papirus", "Adwaita"]
    for fallback in fallback_themes:
        if fallback != theme_name:
            if fallback == "BeautyLine":
                search_paths.extend(build_beautyline_icon_paths(base_name))
            else:
                search_paths.extend(build_theme_icon_paths(base_name, fallback, home))

    if desktop_file_path:
        desktop_dir = os.path.dirname(desktop_file_path)
        search_paths.extend([
            os.path.join(desktop_dir, base_name + ".png"),
            os.path.join(desktop_dir, base_name + ".svg"),
            os.path.join(desktop_dir, icon_name + ".png"),
            os.path.join(desktop_dir, icon_name + ".svg"),
        ])

    search_paths.extend(build_hicolor_icon_paths(base_name, home))

    if desktop_file_path:
        exec_path = read_desktop_file_exec(desktop_file_path)
        if exec_path and os.path.exists(exec_path) and not is_temporary_path(exec_path):
            exec_dir = os.path.dirname(exec_path)
            search_paths.extend([
                os.path.join(exec_dir, base_name + ".png"),
                os.path.join(exec_dir, base_name + ".svg"),
                os.path.join(exec_dir, "..", "resources", "app.png"),
                os.path.join(exec_dir, "..", "resources", "icon.png"),
            ])

    return search_paths


def find_icon_file(
    icon_name: str,
    desktop_file_path: str = "",
    icon_theme: Optional[Gtk.IconTheme] = None
) -> str:
    if not icon_name:
        return ""

    if icon_name.startswith("/"):
        if is_temporary_path(icon_name):
            pass
        elif os.path.exists(icon_name):
            return icon_name

    base_name = normalize_icon_name(icon_name)
    home = os.path.expanduser("~")

    theme_name = ""
    if icon_theme:
        try:
            theme_name = icon_theme.get_theme_name()
        except Exception:
            pass

    search_paths = _build_search_paths(icon_name, base_name, desktop_file_path, theme_name, home)
    return find_icon_in_paths(search_paths)


def _resolve_gicon_direct(
    icon_theme: Gtk.IconTheme,
    gicon: Gio.Icon,
    desktop_file_path: str
) -> Optional[str]:
    try:
        info = icon_theme.lookup_by_gicon(gicon, 64, Gtk.IconLookupFlags.USE_BUILTIN)
        if info and info.get_filename():
            path = info.get_filename()
            if not is_temporary_path(path):
                return path
            if desktop_file_path:
                icon_name = read_desktop_file_icon(desktop_file_path)
                if icon_name:
                    theme_icon = find_icon_file(icon_name, desktop_file_path, icon_theme)
                    if theme_icon and not is_temporary_path(theme_icon):
                        return theme_icon
            return path
    except Exception:
        pass
    return None


def _resolve_themed_icon(
    icon_theme: Gtk.IconTheme,
    gicon: Gio.ThemedIcon
) -> tuple[Optional[str], Optional[str]]:
    icon_name_from_theme = None
    for name in gicon.get_names():
        try:
            info = icon_theme.lookup_icon(name, 64, 0)
            if info and info.get_filename():
                path = info.get_filename()
                if not is_temporary_path(path):
                    return path, name
            if not icon_name_from_theme:
                icon_name_from_theme = name
        except Exception:
            continue
    return None, icon_name_from_theme


def _resolve_file_icon(gicon: Gio.FileIcon) -> Optional[str]:
    try:
        file = gicon.get_file()
        if file:
            path = file.get_path()
            if path and os.path.exists(path) and not is_temporary_path(path):
                return path
    except Exception:
        pass
    return None


def _resolve_gicon_string_fallback(
    icon_theme: Gtk.IconTheme,
    gicon: Gio.Icon,
    desktop_file_path: str
) -> Optional[str]:
    string_repr = gicon.to_string()
    if not string_repr:
        return None

    try:
        info = icon_theme.lookup_icon(string_repr, 64, 0)
        if info and info.get_filename():
            path = info.get_filename()
            if not is_temporary_path(path):
                return path
    except Exception:
        pass

    result = find_icon_file(string_repr, desktop_file_path, icon_theme)
    return result if result else None


def icon_path_from_gicon(
    icon_theme: Gtk.IconTheme,
    gicon: Optional[Gio.Icon],
    desktop_file_path: str = ""
) -> str:
    if not gicon:
        if desktop_file_path:
            icon_name = read_desktop_file_icon(desktop_file_path)
            if icon_name:
                return find_icon_file(icon_name, desktop_file_path, icon_theme)
        return ""

    result = _resolve_gicon_direct(icon_theme, gicon, desktop_file_path)
    if result:
        return result

    icon_name_from_theme = None
    if isinstance(gicon, Gio.ThemedIcon):
        result, icon_name_from_theme = _resolve_themed_icon(icon_theme, gicon)
        if result:
            return result

    if isinstance(gicon, Gio.FileIcon):
        result = _resolve_file_icon(gicon)
        if result:
            return result

    result = _resolve_gicon_string_fallback(icon_theme, gicon, desktop_file_path)
    if result:
        return result

    if icon_name_from_theme:
        result = find_icon_file(icon_name_from_theme, desktop_file_path, icon_theme)
        if result:
            return result

    if desktop_file_path:
        icon_name = read_desktop_file_icon(desktop_file_path)
        if icon_name:
            return find_icon_file(icon_name, desktop_file_path, icon_theme)

    return ""


def collect_apps() -> list[dict]:
    icon_theme = Gtk.IconTheme.get_default()
    apps = []
    seen = set()

    for app in Gio.AppInfo.get_all():
        if app.get_nodisplay() or app.get_is_hidden():
            continue

        name = app.get_display_name() or app.get_name()
        exec_cmd = sanitize_exec(app.get_commandline() or app.get_string("Exec") or "")
        if not name or not exec_cmd:
            continue

        exec_base = exec_cmd.split()[0] if exec_cmd else ""
        key = (name.lower(), exec_base.lower())
        if key in seen:
            continue
        seen.add(key)

        desktop_file_path = app.get_filename() or ""
        icon_path = ""

        try:
            gicon = app.get_icon()
            icon_path = icon_path_from_gicon(icon_theme, gicon, desktop_file_path)
        except Exception:
            if desktop_file_path:
                try:
                    icon_name = read_desktop_file_icon(desktop_file_path)
                    if icon_name:
                        icon_path = find_icon_file(icon_name, desktop_file_path, icon_theme)
                except Exception:
                    pass

        wm_class = ""
        wm_class_aliases = []

        if desktop_file_path:
            wm_class = read_desktop_file_wm_class(desktop_file_path)

            desktop_basename = os.path.basename(desktop_file_path).replace(".desktop", "").lower()
            if desktop_basename and desktop_basename != wm_class.lower():
                wm_class_aliases.append(desktop_basename)

        if not wm_class:
            steam_app_id = extract_steam_app_id(exec_cmd)
            if steam_app_id:
                wm_class = f"steam_app_{steam_app_id}"

        if not wm_class and exec_cmd:
            exec_parts = exec_cmd.split()
            if exec_parts:
                first_cmd = exec_parts[0]
                wm_class = os.path.basename(first_cmd).lower()

        keywords = ""
        if desktop_file_path:
            keywords = read_desktop_file_keywords(desktop_file_path)

        apps.append({
            "name": name,
            "exec": exec_cmd,
            "icon": icon_path,
            "categories": app.get_categories() or "",
            "keywords": keywords,
            "wmClass": wm_class,
            "wmClassAliases": wm_class_aliases,
        })

    return apps


def main() -> int:
    ensure_cache_dir()
    Gtk.init([])
    icon_theme = Gtk.IconTheme.get_default()
    if icon_theme is None:
        raise RuntimeError("Failed to initialize GTK icon theme")

    all_apps = [app for app in Gio.AppInfo.get_all() if app.get_filename()]
    signature = compute_signature(all_apps)

    cached = load_from_cache(signature)
    if cached is not None:
        print(cached)
        return 0

    apps_data = collect_apps()
    json_data = json.dumps(apps_data, ensure_ascii=False)
    save_cache(signature, json_data)
    print(json_data)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        traceback.print_exc()
        print("[]")
        sys.exit(1)
