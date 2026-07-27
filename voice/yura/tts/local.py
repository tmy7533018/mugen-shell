"""In-process speech through sherpa-onnx.

One engine covers every local model family — Piper/VITS and Kokoro differ only
in which files sit in the model directory, which is detected below. That is why
there is no separate Piper implementation: the old one shelled out to the
`piper` binary once per sentence, and that binary was never installed on the
Nix path anyway.
"""

import glob
import io
import os
import threading
import wave

from ..log import log

# Colon-separated, first match wins, so a voice dropped in the writable dir
# shadows a packaged one of the same name.
MODEL_PATH = os.environ.get(
    "YURA_TTS_MODELS",
    os.path.join(
        os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"),
        "mugen-shell", "tts"))


def search_dirs() -> list[str]:
    return [d for d in MODEL_PATH.split(":") if d]


def is_model_dir(path: str) -> bool:
    # An .onnx is the one file every family here has. Without this check a
    # stray directory beside the models can be picked as the fallback voice.
    return bool(glob.glob(os.path.join(path, "*.onnx")))


def find_model(name: str) -> str | None:
    """Locate a model directory by name, refusing anything with a separator."""
    if not name or "/" in name or name.startswith("."):
        return None
    for root in search_dirs():
        path = os.path.join(root, name)
        if os.path.isdir(path) and is_model_dir(path):
            return path
    return None


def available() -> list[str]:
    """Model directory names, nearest search root first, de-duplicated."""
    out: list[str] = []
    for root in search_dirs():
        try:
            entries = sorted(os.listdir(root))
        except OSError:
            continue
        for name in entries:
            if name not in out and is_model_dir(os.path.join(root, name)):
                out.append(name)
    return out


def _config(path: str):
    """Build the sherpa-onnx config for whichever family lives in `path`.

    Kokoro ships a `voices.bin` of speaker embeddings; a Piper/VITS voice is a
    lone .onnx beside its tokens. Nothing else distinguishes them.
    """
    import sherpa_onnx

    tokens = os.path.join(path, "tokens.txt")
    data_dir = os.path.join(path, "espeak-ng-data")
    dict_dir = os.path.join(path, "dict")
    voices = os.path.join(path, "voices.bin")
    lexicons = ",".join(sorted(glob.glob(os.path.join(path, "lexicon*.txt"))))

    if os.path.exists(voices):
        model = os.path.join(path, "model.onnx")
        if not os.path.exists(model):
            model = os.path.join(path, "model.int8.onnx")
        kokoro = sherpa_onnx.OfflineTtsKokoroModelConfig(
            model=model, voices=voices, tokens=tokens,
            data_dir=data_dir if os.path.isdir(data_dir) else "",
            dict_dir=dict_dir if os.path.isdir(dict_dir) else "",
            lexicon=lexicons)
        return sherpa_onnx.OfflineTtsModelConfig(kokoro=kokoro, num_threads=2)

    onnx = [f for f in sorted(glob.glob(os.path.join(path, "*.onnx")))
            if not f.endswith(".int8.onnx")] or sorted(
                glob.glob(os.path.join(path, "*.onnx")))
    if not onnx:
        raise RuntimeError(f"no .onnx model in {path}")
    vits = sherpa_onnx.OfflineTtsVitsModelConfig(
        model=onnx[0], tokens=tokens,
        data_dir=data_dir if os.path.isdir(data_dir) else "",
        dict_dir=dict_dir if os.path.isdir(dict_dir) else "",
        lexicon=lexicons)
    return sherpa_onnx.OfflineTtsModelConfig(vits=vits, num_threads=2)


_cache: dict[str, object] = {}
_cache_lock = threading.Lock()


def _load(path: str):
    # Loading costs seconds and hundreds of MB, and the synthesis producer
    # thread would otherwise pay it again on every sentence.
    with _cache_lock:
        if path not in _cache:
            import sherpa_onnx
            log("tts", f"loading {os.path.basename(path)}")
            _cache[path] = sherpa_onnx.OfflineTts(
                sherpa_onnx.OfflineTtsConfig(model=_config(path),
                                             max_num_sentences=1))
        return _cache[path]


class LocalEngine:
    """Speaks with a model directory named by the `local:` / `piper:` prefix."""

    def __init__(self, name: str, speaker: int = 0):
        path = find_model(name)
        if path is None:
            raise RuntimeError(f"no TTS model named {name!r} in {MODEL_PATH}")
        self.path = path
        self.speaker = speaker

    def synth(self, sentence: str, speed: float) -> bytes:
        import numpy as np

        audio = _load(self.path).generate(sentence, sid=self.speaker, speed=speed)
        samples = np.asarray(audio.samples, dtype=np.float32)
        pcm = (np.clip(samples, -1.0, 1.0) * 32767).astype(np.int16)
        buf = io.BytesIO()
        with wave.open(buf, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(audio.sample_rate)
            w.writeframes(pcm.tobytes())
        return buf.getvalue()
