"""Runs the HTTP TTS engine only around the turns that need it.

AivisSpeech costs ~2.7 GB and unloading its voice models frees none of it, so
only stopping the process gives the memory back. Start and first answer are
~4.8 s apart, which is why prewarm() fires at the trigger and not at synthesis.
"""

import os
import subprocess
import threading
import time

import requests

from ..log import log
from ..settings import voice_float

# Empty means nothing to manage: stopping a service the user started
# themselves would be rude.
SERVICE = os.environ.get("YURA_TTS_SERVICE", "")
ENGINE = "aivis"
READY_TIMEOUT_S = float(os.environ.get("YURA_TTS_READY_TIMEOUT", "40"))
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
    """Ask systemd for the engine and return; the caller has work to do."""
    if not managed():
        return
    mark_used()
    _watch()
    threading.Thread(target=_systemctl, args=("start",), daemon=True).start()


def wait_ready(base_url: str) -> bool:
    """Block until the engine answers, or give up after READY_TIMEOUT_S."""
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
            if time.time() >= deadline:
                log("tts", f"engine did not come up within {READY_TIMEOUT_S:.0f}s")
                return False
            if not logged:
                log("tts", "waiting for the engine to come up")
                logged = True
            time.sleep(0.5)


def revive(base_url: str) -> bool:
    """Bring the engine back after a request found it gone."""
    if not managed():
        return False
    prewarm()
    return wait_ready(base_url)


def _systemctl(verb: str) -> None:
    r = subprocess.run(["systemctl", "--user", verb, "--no-block", SERVICE],
                       capture_output=True, text=True)
    if r.returncode != 0:
        log("tts", f"systemctl {verb} {SERVICE}: {r.stderr.strip()}")


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
        log("tts", f"engine idle for {idle_min:.0f} min, stopping")
        _systemctl("stop")
