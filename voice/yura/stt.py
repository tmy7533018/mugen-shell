import os
import subprocess
import time

import requests

from .const import STT_LANG
from .log import log
from .settings import voice_settings

WHISPER_URL = os.environ.get("YURA_WHISPER_URL", "http://127.0.0.1:8178")
WHISPER_BIN = os.environ.get(
    "YURA_WHISPER_BIN",
    os.path.expanduser("~/.local/src/whisper.cpp/build/bin/whisper-server"))
WHISPER_MODEL = os.environ.get(
    "YURA_WHISPER_MODEL",
    os.path.expanduser("~/.local/share/whisper/ggml-large-v3-turbo.bin"))


def ensure_whisper_server() -> subprocess.Popen | None:
    try:
        requests.get(WHISPER_URL, timeout=1)
        log("whisper", "already running")
        return None
    except requests.RequestException:
        pass
    port = WHISPER_URL.rsplit(":", 1)[1]
    log("whisper", f"starting {WHISPER_BIN} (port {port})")
    proc = subprocess.Popen(
        [WHISPER_BIN, "-m", WHISPER_MODEL, "--host", "127.0.0.1",
         "--port", port, "-l", STT_LANG],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    deadline = time.time() + 60
    while time.time() < deadline:
        if proc.poll() is not None:
            raise RuntimeError("whisper-server exited during startup")
        try:
            requests.get(WHISPER_URL, timeout=1)
            log("whisper", "ready")
            return proc
        except requests.RequestException:
            time.sleep(0.5)
    raise RuntimeError("whisper-server did not come up in 60s")


def transcribe(wav: bytes) -> str:
    # Per-request language wins over the server's -l startup default,
    # so the Settings knob applies without a whisper-server restart.
    lang = str(voice_settings().get("sttLang", STT_LANG))
    r = requests.post(
        f"{WHISPER_URL}/inference",
        files={"file": ("speech.wav", wav, "audio/wav")},
        data={"response_format": "json", "temperature": "0.0",
              "language": lang},
        timeout=60)
    r.raise_for_status()
    return r.json().get("text", "").strip()
