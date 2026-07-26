#!/usr/bin/env python3
import sys
import json
import re
import subprocess
import os


# A Lua Hyprland config evaluates `hyprctl dispatch` args as Lua, so the legacy
# "focuswindow address:0x…" string is rejected and the hl.dsp.* form is
# required. HYPR_CONFIG_LUA is exported by the Lua config itself; the systeminfo
# probe covers a session that never exported it. Mirrors idle-timer.sh and
# shell/lib/Hypr.qml.
def is_lua_config():
    if os.environ.get("HYPR_CONFIG_LUA") == "1":
        return True
    try:
        info = subprocess.run(['hyprctl', 'systeminfo'], capture_output=True,
                              text=True, timeout=3)
        return re.search(r'^configProvider:\s*lua\s*$', info.stdout, re.M) is not None
    except Exception:
        return False

def get_hyprland_clients():
    try:
        result = subprocess.run(['hyprctl', 'clients', '-j'], capture_output=True, text=True)
        if result.returncode == 0:
            return json.loads(result.stdout)
    except Exception as e:
        print(f"Error getting clients: {e}", file=sys.stderr)
    return []

def launch_app(desktop_entry):
    try:
        print(f"Launching {desktop_entry}...", file=sys.stderr)
        subprocess.Popen(['gtk-launch', desktop_entry], start_new_session=True)
    except Exception as e:
        print(f"Error launching app: {e}", file=sys.stderr)

def focus_window(address):
    if is_lua_config():
        cmd = ['hyprctl', 'dispatch',
               'hl.dsp.focus({ window = "address:%s" })' % address]
    else:
        cmd = ['hyprctl', 'dispatch', 'focuswindow', f"address:{address}"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
    except Exception as e:
        print(f"Error focusing window: {e}", file=sys.stderr)
        return False
    # hyprctl exits 0 even when Hyprland rejects the dispatch, so the reply body
    # is the only signal that the window actually got focused.
    reply = (result.stdout or '').strip()
    if reply != 'ok':
        print(f"Focus rejected for {address}: {reply or result.stderr.strip()}",
              file=sys.stderr)
        return False
    return True

def main():
    if len(sys.argv) < 2:
        print("Usage: focus_or_launch.py <desktop_entry>", file=sys.stderr)
        sys.exit(1)

    desktop_entry = sys.argv[1]

    search_term = desktop_entry.lower()
    if search_term.endswith('.desktop'):
        search_term = search_term[:-8]

    clients = get_hyprland_clients()
    focused = None

    for client in clients:
        cls = client.get('class', '').lower()
        initial_cls = client.get('initialClass', '').lower()

        if search_term == cls or search_term == initial_cls:
            focused = focus_window(client['address'])
            break

        if (search_term in cls) or (cls in search_term):
            focused = focus_window(client['address'])
            break

        if (search_term in initial_cls) or (initial_cls in search_term):
            focused = focus_window(client['address'])
            break

    if focused is None:
        launch_app(desktop_entry)
        return 0
    return 0 if focused else 1

if __name__ == "__main__":
    sys.exit(main())
