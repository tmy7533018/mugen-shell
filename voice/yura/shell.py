import os
import queue
import subprocess
import threading

from .const import QS_CONFIG_DIR

YURA_SHELL_QML = os.path.join(QS_CONFIG_DIR, "yura-shell.qml")


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


def yura_ipc(*args: str) -> None:
    # yura-shell is a separate quickshell process, addressed by -p.
    _ipc_async(["qs", "-p", YURA_SHELL_QML, "ipc", "call", "yura", *args])


# IPC is fire-and-forget, so neither surface can be asked what it shows — GET /state answers from here.
_state = {"speaking": False}
_state_lock = threading.Lock()


def state() -> dict:
    with _state_lock:
        return dict(_state)


def _record(key: str, on: bool) -> None:
    with _state_lock:
        _state[key] = on


def set_speaking(on: bool) -> None:
    # The bar holds its auto-close while the spoken reply is playing.
    _record("speaking", on)
    flag = "true" if on else "false"
    shell_ipc("yura", "set_speaking", flag)
    yura_ipc("set_speaking", flag)
