import os
import subprocess
import threading
import time

import requests

from ..log import log
from ..settings import voice_float

SERVICE = os.environ.get("YURA_TTS_SERVICE", "")
ENGINE = "aivis"
READY_TIMEOUT_S = float(os.environ.get("YURA_TTS_READY_TIMEOUT", "40"))
_start_failed = False
IDLE_STOP_MIN = 10.0

_lock = threading.Lock()
_last_used = 0.0
_watching = False


def managed(engine: str = ENGINE) -> bool:
    return bool(SERVICE) and engine == ENGINE


def mark_used() -> None:
    global _last_used
    with _lock:
        _last_used = time.time()


def prewarm() -> None:
    if not managed():
        return
    mark_used()
    _watch()
    threading.Thread(target=_systemctl, args=("start",), daemon=True).start()


def wait_ready(base_url: str) -> bool:
    if not managed():
        return True
    deadline = time.time() + READY_TIMEOUT_S
    logged = False
    while True:
        try:
            requests.get(f"{base_url}/speakers", timeout=2).raise_for_status()
            if logged:
                log("tts", "engine ready")
            mark_used()
            return True
        except requests.RequestException:
            if _start_failed:
                # A unit that is missing or refuses to start is never going to
                # answer; waiting out the window would stall the voice picker
                # every time it opens.
                log("tts", f"{SERVICE} did not start, not waiting for it")
                return False
            if time.time() >= deadline:
                log("tts", f"engine did not come up within {READY_TIMEOUT_S:.0f}s")
                return False
            if not logged:
                log("tts", "waiting for the engine to come up")
                logged = True
            time.sleep(0.5)


def revive(base_url: str) -> bool:
    if not managed():
        return False
    prewarm()
    return wait_ready(base_url)


def _systemctl(verb: str) -> None:
    global _start_failed
    r = subprocess.run(["systemctl", "--user", verb, "--no-block", SERVICE],
                       capture_output=True, text=True)
    if r.returncode != 0:
        log("tts", f"systemctl {verb} {SERVICE}: {r.stderr.strip()}")
    if verb == "start":
        _start_failed = r.returncode != 0


def _watch() -> None:
    global _watching
    with _lock:
        if _watching:
            return
        _watching = True
    threading.Thread(target=_watchdog, daemon=True).start()


def _watchdog() -> None:
    global _last_used
    while True:
        time.sleep(30)
        idle_min = voice_float("idleStopMin", IDLE_STOP_MIN, 1.0, 240.0)
        with _lock:
            idle_for = time.time() - _last_used if _last_used else 0.0
            if idle_for <= idle_min * 60:
                continue
            _last_used = 0.0
            # prewarm() takes this lock, so a stop decided outside it can undo a fresh start.
            log("tts", f"engine idle for {idle_min:.0f} min, stopping")
            _systemctl("stop")
