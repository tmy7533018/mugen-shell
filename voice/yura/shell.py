import os
import queue
import subprocess
import threading

YURA_SHELL_QML = os.path.expanduser(
    "~/.config/quickshell/mugen-shell/yura-shell.qml")


_ipc_queue: queue.Queue[list[str]] = queue.Queue()


def _ipc_worker() -> None:
    while True:
        cmd = _ipc_queue.get()
        try:
            subprocess.run(cmd, capture_output=True, timeout=3)
        except Exception:
            pass


threading.Thread(target=_ipc_worker, daemon=True).start()


def _ipc_async(cmd: list[str]) -> None:
    _ipc_queue.put(cmd)


def shell_ipc(*args: str) -> None:
    _ipc_async(["qs", "-c", "mugen-shell", "ipc", "call", *args])


def shell_ipc_read(*args: str) -> str:
    try:
        r = subprocess.run(
            ["qs", "-c", "mugen-shell", "ipc", "call", *args],
            capture_output=True, text=True, timeout=3)
        return r.stdout.strip()
    except Exception:
        return ""


def yura_ipc(*args: str) -> None:
    # yura-shell is a separate quickshell process, addressed by -p.
    _ipc_async(["qs", "-p", YURA_SHELL_QML, "ipc", "call", "yura", *args])


# Both surfaces are told over fire-and-forget IPC, so neither can be asked what
# it currently shows. Recording the same flags here gives GET /state something
# authoritative to answer with when a surface loses track.
_state = {"thinking": False, "listening": False, "speaking": False}
_state_lock = threading.Lock()


def state() -> dict:
    with _state_lock:
        return dict(_state)


def _record(key: str, on: bool) -> None:
    with _state_lock:
        _state[key] = on


def set_thinking(on: bool) -> None:
    _record("thinking", on)
    shell_ipc("yura", "set_thinking", "true" if on else "false")


def set_listening(on: bool) -> None:
    _record("listening", on)
    flag = "true" if on else "false"
    shell_ipc("yura", "set_listening", flag)
    yura_ipc("set_listening", flag)


def set_speaking(on: bool) -> None:
    # The bar holds its auto-close while the spoken reply is playing.
    _record("speaking", on)
    flag = "true" if on else "false"
    shell_ipc("yura", "set_speaking", flag)
    yura_ipc("set_speaking", flag)


def open_panel() -> None:
    yura_ipc("open")
