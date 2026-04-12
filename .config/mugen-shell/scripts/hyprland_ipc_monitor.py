#!/usr/bin/env python3
"""Monitor Hyprland IPC events and print workspace/window changes to stdout."""
import socket
import os
import sys

def find_hyprland_socket():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR")
    if sig and runtime_dir:
        sock_path = os.path.join(runtime_dir, "hypr", sig, ".socket2.sock")
        if os.path.exists(sock_path):
            return sock_path

    runtime_dir = os.environ.get('XDG_RUNTIME_DIR')
    if runtime_dir:
        hypr_dir = os.path.join(runtime_dir, 'hypr')
        if os.path.exists(hypr_dir):
            instances = os.listdir(hypr_dir)
            if instances:
                sock_path = os.path.join(hypr_dir, instances[0], '.socket2.sock')
                if os.path.exists(sock_path):
                    return sock_path

    tmp_hypr = '/tmp/hypr'
    if os.path.exists(tmp_hypr):
        instances = os.listdir(tmp_hypr)
        if instances:
            sock_path = os.path.join(tmp_hypr, instances[0], '.socket2.sock')
            if os.path.exists(sock_path):
                return sock_path

    return None

def main():
    sock_path = find_hyprland_socket()
    if not sock_path:
        print("Hyprland IPC socket not found", file=sys.stderr)
        sys.exit(1)

    relevant_events = [
        'workspace', 'window', 'move', 'focus', 'monitor',
        'movewindow', 'moveworkspace', 'focusedmon', 'focusedmonv2',
        'workspacev2', 'windowtitle', 'activewindow', 'activewindowv2'
    ]

    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.connect(sock_path)
        print(f"connected:{sock_path}", file=sys.stderr, flush=True)

        while True:
            try:
                data = s.recv(4096).decode('utf-8', errors='ignore')
                if not data:
                    break

                for line in data.strip().split('\n'):
                    if not line or '>>' not in line:
                        continue

                    event_type = line.split('>>')[0].lower()

                    if any(keyword in event_type for keyword in relevant_events):
                        print(line, flush=True)

            except (socket.error, OSError) as e:
                print(f"Socket error: {e}", file=sys.stderr)
                break

    except KeyboardInterrupt:
        pass
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        s.close()

if __name__ == '__main__':
    main()
