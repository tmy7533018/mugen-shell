#!/usr/bin/env python3
import sys
import json
import subprocess
import os

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
    try:
        print(f"Focusing window {address}...", file=sys.stderr)
        subprocess.run(['hyprctl', 'dispatch', 'focuswindow', f"address:{address}"])
    except Exception as e:
        print(f"Error focusing window: {e}", file=sys.stderr)

def main():
    if len(sys.argv) < 2:
        print("Usage: focus_or_launch.py <desktop_entry>", file=sys.stderr)
        sys.exit(1)

    desktop_entry = sys.argv[1]

    search_term = desktop_entry.lower()
    if search_term.endswith('.desktop'):
        search_term = search_term[:-8]

    clients = get_hyprland_clients()
    found = False

    for client in clients:
        cls = client.get('class', '').lower()
        initial_cls = client.get('initialClass', '').lower()

        if search_term == cls or search_term == initial_cls:
            focus_window(client['address'])
            found = True
            break

        if (search_term in cls) or (cls in search_term):
            focus_window(client['address'])
            found = True
            break

        if (search_term in initial_cls) or (initial_cls in search_term):
            focus_window(client['address'])
            found = True
            break

    if not found:
        launch_app(desktop_entry)

if __name__ == "__main__":
    main()
