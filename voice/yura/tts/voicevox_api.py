"""AivisSpeech and VOICEVOX.

One implementation for both: AivisSpeech speaks the same audio_query/synthesis
API, just on another port.
"""

import os

import requests

from ..log import log
from . import service

VOICEVOX_URL = os.environ.get("YURA_VOICEVOX_URL", "http://127.0.0.1:50021")
AIVIS_URL = os.environ.get("YURA_AIVIS_URL", "http://127.0.0.1:10101")
VOICEVOX_SPEAKER = int(os.environ.get("YURA_VOICEVOX_SPEAKER", "14"))

BASE_URLS = {"aivis": AIVIS_URL, "voicevox": VOICEVOX_URL}

_default_sid_cache: dict[str, int] = {}


def style_id(voice: str) -> int | None:
    # Hand-edited settings must degrade to the default voice, not crash
    # the turn sentence by sentence.
    try:
        return int(voice)
    except ValueError:
        log("tts", f"bad style id {voice!r}, using default voice")
        return None


def default_style_id(base_url: str) -> int | None:
    """First style the engine reports, cached per engine.

    Lets a voice setting name only the engine ("aivis:"): the style ids depend
    on which models are installed, so a deployment can't pin one up front.
    """
    if base_url in _default_sid_cache:
        return _default_sid_cache[base_url]
    try:
        r = requests.get(f"{base_url}/speakers", timeout=3)
        r.raise_for_status()
        sid = int(r.json()[0]["styles"][0]["id"])
    except Exception as e:
        log("tts", f"no default style from {base_url}: {e}")
        return None
    _default_sid_cache[base_url] = sid
    return sid


class VoicevoxEngine:
    def __init__(self, engine: str, voice: str):
        self.base_url = BASE_URLS.get(engine, VOICEVOX_URL)
        self.managed = service.managed(engine)
        if self.managed:
            service.wait_ready(self.base_url)
        sid = style_id(voice) if voice else None
        if sid is None:
            sid = default_style_id(self.base_url)
        if sid is None:
            sid = VOICEVOX_SPEAKER
        self.speaker = sid

    def synth(self, sentence: str, speed: float) -> bytes:
        try:
            return self._synth(sentence, speed)
        except requests.RequestException:
            if not self.managed or not service.revive(self.base_url):
                raise
            return self._synth(sentence, speed)

    def _synth(self, sentence: str, speed: float) -> bytes:
        q = requests.post(f"{self.base_url}/audio_query",
                          params={"text": sentence, "speaker": self.speaker},
                          timeout=10).json()
        q["speedScale"] = speed
        r = requests.post(f"{self.base_url}/synthesis",
                          params={"speaker": self.speaker}, json=q, timeout=60)
        r.raise_for_status()
        service.mark_used()
        return r.content
