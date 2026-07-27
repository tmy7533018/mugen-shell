import os
import subprocess
import threading

YURA_SHELL_QML = os.path.expanduser(
    "~/.config/quickshell/mugen-shell/yura-shell.qml")


# Fire-and-forget: the pipeline must survive without the shell, and an inline
# qs launch is slow enough to delay capture and gap the spoken sentences.
def _ipc_async(cmd: list[str]) -> None:
    def run():
        try:
            subprocess.run(cmd, capture_output=True, timeout=3)
        except Exception:
            pass
    threading.Thread(target=run, daemon=True).start()


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


def set_thinking(on: bool) -> None:
    shell_ipc("yura", "set_thinking", "true" if on else "false")


def set_listening(on: bool) -> None:
    flag = "true" if on else "false"
    shell_ipc("yura", "set_listening", flag)
    yura_ipc("set_listening", flag)


def set_speaking(on: bool) -> None:
    # The bar holds its auto-close while the spoken reply is playing.
    flag = "true" if on else "false"
    shell_ipc("yura", "set_speaking", flag)
    yura_ipc("set_speaking", flag)


def open_panel() -> None:
    yura_ipc("open")
