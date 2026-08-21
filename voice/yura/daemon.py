"""Yura's speech daemon: it owns the control socket and nothing else.

Speech is driven entirely by the UI over that socket; the daemon holds no
conversation of its own.
"""
import os
import signal
import time

from .control import ReadAloud, serve_control_socket
from .log import log
from .settings import voice_settings
from .shell import state as shell_state


class Daemon:
    def __init__(self):
        self.running = True
        self.read_aloud = ReadAloud()

    def state(self) -> dict:
        return shell_state()

    def run(self) -> None:
        log("ready", "read-aloud only")
        # Polled, not watched: settings.json is the only way this is turned off.
        while self.running and voice_settings().get("enabled", True):
            time.sleep(1.0)


def main() -> None:
    daemon = Daemon()

    def stop(*_):
        daemon.running = False
        os._exit(0)

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    serve_control_socket(daemon)
    daemon.run()
