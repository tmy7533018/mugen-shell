import os
import subprocess

import requests

from ..log import log
from ..settings import voice_float, voice_settings

VOICEVOX_URL = os.environ.get("YURA_VOICEVOX_URL", "http://127.0.0.1:50021")
# AivisSpeech speaks the same audio_query/synthesis API, just elsewhere.
AIVIS_URL = os.environ.get("YURA_AIVIS_URL", "http://127.0.0.1:10101")
VOICEVOX_SPEAKER = int(os.environ.get("YURA_VOICEVOX_SPEAKER", "14"))
TTS_SPEED = float(os.environ.get("YURA_VOICE_SPEED", "1.0"))
# Fallback voice when settings.json names none, as "<engine>:<style-id>" or
# just "<engine>:" to take that engine's first style.
TTS_DEFAULT = os.environ.get("YURA_TTS", "")
# Piper is the non-Japanese TTS path; voices are bare names resolved here.
PIPER_BIN = os.environ.get("YURA_PIPER_BIN", "piper")
PIPER_VOICES_DIR = os.path.expanduser(
    os.environ.get("YURA_PIPER_VOICES", "~/.local/share/piper/voices"))


def _style_id(voice: str) -> int | None:
    # Hand-edited settings must degrade to the default voice, not crash
    # the turn sentence by sentence.
    try:
        return int(voice)
    except ValueError:
        log("tts", f"bad style id {voice!r}, using default voice")
        return None


_engine_sid_cache: dict[str, int] = {}


def _engine_default_sid(base_url: str) -> int | None:
    """First style the engine reports, cached per engine.

    Lets a voice setting name only the engine ("aivis:"): the style ids depend
    on which models are installed, so a deployment can't pin one up front.
    """
    if base_url in _engine_sid_cache:
        return _engine_sid_cache[base_url]
    try:
        r = requests.get(f"{base_url}/speakers", timeout=3)
        r.raise_for_status()
        sid = int(r.json()[0]["styles"][0]["id"])
    except Exception as e:
        log("tts", f"no default style from {base_url}: {e}")
        return None
    _engine_sid_cache[base_url] = sid
    return sid


def synth_voicevox(base_url: str, speaker: int, sentence: str, speed: float) -> bytes:
    q = requests.post(f"{base_url}/audio_query",
                      params={"text": sentence, "speaker": speaker},
                      timeout=10).json()
    q["speedScale"] = speed
    r = requests.post(f"{base_url}/synthesis",
                      params={"speaker": speaker}, json=q, timeout=60)
    r.raise_for_status()
    return r.content


def synth_piper(voice: str, sentence: str, speed: float) -> bytes:
    model = voice if os.path.isabs(voice) else os.path.join(
        PIPER_VOICES_DIR, voice + ".onnx")
    p = subprocess.run(
        [PIPER_BIN, "--model", model, "--length_scale", f"{1.0 / speed:.2f}",
         "--output_file", "-"],
        input=sentence.encode(), capture_output=True, timeout=30)
    if p.returncode != 0:
        raise RuntimeError(f"piper: {p.stderr.decode(errors='replace')[-200:]}")
    return p.stdout


def synthesize(sentence: str) -> bytes:
    # Settings.json wins over the env fallback so a change applies from the
    # next sentence. voice.tts is "<engine>:<voice>" — the voice choice
    # carries the engine, there is no separate engine setting.
    vs = voice_settings()
    # Clamped so a hand-edited settings.json can't zero the length_scale divisor.
    speed = voice_float("speed", TTS_SPEED, 0.5, 2.0)
    engine, _, voice = str(vs.get("tts", "") or TTS_DEFAULT).partition(":")
    if engine == "piper" and voice:
        return synth_piper(voice, sentence, speed)
    sid = _style_id(voice) if voice else None
    if engine == "aivis":
        if sid is None:
            sid = _engine_default_sid(AIVIS_URL)
        if sid is not None:
            return synth_voicevox(AIVIS_URL, sid, sentence, speed)
    if engine != "voicevox" or sid is None:
        sid = int(voice_float("speaker", VOICEVOX_SPEAKER, 0, 2 ** 31 - 1))
    return synth_voicevox(VOICEVOX_URL, sid, sentence, speed)
