"""Picks the engine for a sentence and keeps the choice stable.

Routing is per utterance, never per sentence: switching voice midway through
one reply is worse than speaking all of it in the less apt one.
"""

import os
import threading

import requests

from ..lang import configured_lang
from ..log import log
from ..settings import voice_float, voice_settings
from . import service
from .base import Engine, split_voice
from .local import LocalEngine, available, find_model
from .voicevox_api import BASE_URLS, VoicevoxEngine

# Fallback voice as "<engine>:<voice>", or "<engine>:" to take that engine's first style.
TTS_DEFAULT = os.environ.get("YURA_TTS", "")
TTS_SPEED = float(os.environ.get("YURA_VOICE_SPEED", "1.0"))

_engines: dict[str, Engine] = {}
_lock = threading.Lock()


def configured_voice() -> str:
    """The `"<engine>:<voice>"` this turn should speak with.

    voice.ttsByLang overrides voice.tts for the chosen language, which is how
    Japanese keeps AivisSpeech while everything else uses the local model.
    """
    vs = voice_settings()
    lang = configured_lang()
    if lang:
        by_lang = vs.get("ttsByLang")
        if isinstance(by_lang, dict) and by_lang.get(lang):
            return str(by_lang[lang])
    return str(vs.get("tts", "") or TTS_DEFAULT)


def prewarm(voice: str | None = None) -> None:
    engine, _ = split_voice(voice if voice is not None else configured_voice())
    if service.managed(engine):
        service.prewarm()


def _build(value: str) -> Engine:
    engine, voice = split_voice(value)
    if engine in BASE_URLS:
        return VoicevoxEngine(engine, voice)
    if engine in ("local", "piper") and voice and find_model(voice):
        return LocalEngine(voice)
    # A typo in settings.json must not cost the whole reply, so degrade to an installed voice.
    names = available()
    if names:
        if value:
            log("tts", f"unknown voice {value!r}, using {names[0]}")
        return LocalEngine(names[0])
    raise RuntimeError(f"no engine for {value!r} and no local model installed")


def engine_for(value: str) -> Engine:
    with _lock:
        if value not in _engines:
            _engines[value] = _build(value)
        return _engines[value]


def synthesize(sentence: str, voice: str | None = None) -> bytes:
    if voice is None:
        voice = configured_voice()
    # Clamped so a hand-edited settings.json can't zero the length_scale divisor.
    speed = voice_float("speed", TTS_SPEED, 0.5, 2.0)
    return engine_for(voice).synth(sentence, speed)


def _pretty(name: str) -> str:
    # The zoo names every Piper voice "vits-piper-<locale>-<voice>-<quality>"; the prefix is noise.
    for junk in ("vits-piper-", "vits-"):
        if name.startswith(junk):
            return name[len(junk):]
    return name


def catalog() -> list[dict]:
    """Every voice the user could pick, for the Settings picker.

    Assembled here because the daemon already knows which engines exist and
    which models are installed; asking the shell to rediscover that meant three
    separate probes and a second copy of the naming rules.
    """
    service.prewarm()
    out = [{"value": f"local:{name}", "label": _pretty(name), "engine": "local"}
           for name in available()]
    for engine, base_url in BASE_URLS.items():
        if service.managed(engine):
            service.wait_ready(base_url)
        try:
            r = requests.get(f"{base_url}/speakers", timeout=2)
            r.raise_for_status()
            speakers = r.json()
        except Exception:
            continue  # engine not running; its voices simply aren't offered
        for sp in speakers:
            for st in sp.get("styles", []):
                out.append({
                    "value": f"{engine}:{st['id']}",
                    "label": f"{sp['name']} ({st['name']})",
                    "engine": engine,
                })
    return out
