import io
import os
import queue
import re
import threading
import time
import wave
from collections.abc import Iterable, Iterator

import numpy as np
import sounddevice as sd

from ..log import log
from ..settings import voice_float
from ..shell import set_speaking
from .router import configured_voice, synthesize

# Engines master at very different loudness, so every clip is RMS-normalized to keep swaps inaudible.
TTS_TARGET_DBFS = float(os.environ.get("YURA_TTS_TARGET_DBFS", "-23"))

_MD_JUNK = re.compile(r"```.*?```|`|[*_#>]|\[([^\]]*)\]\([^)]*\)", re.S)
_EMOJI = re.compile(r"[\U0001F000-\U0001FAFF☀-➿️]")


def clean_for_speech(text: str) -> str:
    text = _MD_JUNK.sub(lambda m: m.group(1) or " ", text)
    text = _EMOJI.sub("", text)
    return re.sub(r"[ \t]+", " ", text).strip()


# ASCII periods only count at a whitespace boundary so decimals survive.
_SENTENCE_END = re.compile(r"(?<=[。!?！？\n])|(?<=\.)\s+")
MIN_SENTENCE = 8


def _cut(buf: str, final: bool, hold_short: bool = True) -> tuple[list[str], str]:
    """Sentences ready to speak, plus text not yet known to be a whole sentence."""
    parts = _SENTENCE_END.split(buf)
    tail = "" if final else parts.pop()
    out: list[str] = []
    for s in (p.strip() for p in parts):
        if not s:
            continue
        # Glue tiny fragments to the previous sentence so TTS doesn't gasp.
        if out and len(s) < MIN_SENTENCE:
            out[-1] += s
        else:
            out.append(s)
    # Its previous sentence is already spoken, so a short first piece joins what follows instead.
    if not final and hold_short and out and len(out[0]) < MIN_SENTENCE:
        if len(out) > 1:
            out[1] = out[0] + out[1]
        else:
            tail = out[0] + tail
        out.pop(0)
    return out, tail


def split_sentences(text: str) -> list[str]:
    return _cut(text, final=True)[0]


def stream_sentences(chunks: Iterable[str]) -> Iterator[str]:
    """Speakable sentences from a reply that is still being generated."""
    buf = ""
    started = False

    def speakable(sentences):
        nonlocal started
        for s in sentences:
            if spoken := clean_for_speech(s):
                started = True
                yield spoken

    for chunk in chunks:
        # Speaking the first sentence early is the whole point, so it never waits for a neighbour.
        ready, buf = _cut(buf + chunk, final=False, hold_short=started)
        yield from speakable(ready)
    yield from speakable(_cut(buf, final=True)[0])


def join_spoken(parts: list[str]) -> str:
    # Latin sentences need back the space split_sentences consumed; Japanese keeps running flush.
    out = ""
    for p in parts:
        if out and out[-1] in ".!?":
            out += " "
        out += p
    return out


def play_wav(data: bytes, should_stop=None) -> None:
    with wave.open(io.BytesIO(data), "rb") as w:
        sr = w.getframerate()
        channels = w.getnchannels()
        audio = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
    if channels > 1:
        audio = audio.reshape(-1, channels)
    x = audio.astype(np.float32) / 32768.0
    vol = voice_float("volume", 1.0, 0.0, 1.0)
    if vol <= 0.0:
        # Return instead of pushing a silent buffer, which would hold the speaking state for nothing.
        return
    rms = float(np.sqrt(np.mean(x * x)))
    if rms > 1e-4:
        # Boost stays capped so quiet styles don't get their noise floor dragged up.
        gain = min(10 ** (TTS_TARGET_DBFS / 20) / rms * vol, 3.0)
        audio = (np.clip(x * gain, -1.0, 1.0) * 32767).astype(np.int16)
    sd.play(audio, sr)
    if should_stop is None:
        sd.wait()
        return
    # Poll while the sentence plays so a cancel cuts it off instead of waiting for the next boundary.
    stream = sd.get_stream()
    while stream.active:
        if should_stop():
            sd.stop()
            break
        time.sleep(0.03)


def speak(text: str | Iterable[str], on_sentence=None, should_stop=None,
          voice=None) -> None:
    sentences = (split_sentences(clean_for_speech(text)) if isinstance(text, str)
                 else text)
    # Resolved once: a settings change mid-reply must not swap the voice between two sentences.
    if voice is None:
        voice = configured_voice()
    # One-ahead synthesis pipeline: synth sentence N+1 while N plays.
    q: queue.Queue[tuple[str, bytes] | None] = queue.Queue(maxsize=2)
    # Set once the consumer stops draining, so the producer never parks forever on a full queue.
    done = threading.Event()

    def put(item) -> bool:
        while not done.is_set():
            try:
                q.put(item, timeout=0.2)
                return True
            except queue.Full:
                continue
        return False

    def producer():
        try:
            for s in sentences:
                if done.is_set() or not put((s, synthesize(s, voice))):
                    return
        except Exception as e:
            log("tts", f"synthesis failed: {e}")
        finally:
            put(None)

    threading.Thread(target=producer, daemon=True).start()
    try:
        while (item := q.get()) is not None:
            if should_stop and should_stop():
                log("tts", "stopped")
                break
            sentence, wav = item
            if on_sentence:
                on_sentence(sentence)
            play_wav(wav, should_stop=should_stop)
    finally:
        done.set()
        while not q.empty():
            try:
                q.get_nowait()
            except queue.Empty:
                break


# sounddevice's module-level play/stop share one output stream, so a reply and /speak would collide.
_playback = threading.Lock()


def speak_guarded(text: str | Iterable[str], on_sentence=None, should_stop=None,
                  voice=None) -> None:
    with _playback:
        # Every audible reply must raise yuraSpeaking, which the bar holds auto-close on.
        set_speaking(True)
        try:
            speak(text, on_sentence, should_stop=should_stop, voice=voice)
        finally:
            set_speaking(False)
