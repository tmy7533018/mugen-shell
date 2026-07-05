#!/usr/bin/env python3
"""Yura voice daemon.

Pipeline: mic -> wake word (openWakeWord) -> VAD-endpointed capture ->
whisper.cpp server (STT) -> mugen-ai /chat -> VOICEVOX (TTS) -> speakers.

Run from a terminal inside the graphical session so `qs ipc` reaches the
shell. All knobs are env vars; see CONFIG below.
"""

import io
import json
import os
import queue
import re
import signal
import subprocess
import sys
import threading
import time
import wave

import numpy as np
import requests
import sounddevice as sd
from openwakeword.model import Model as WakeModel

# CONFIG ---------------------------------------------------------------
AI_URL = f"http://127.0.0.1:{os.environ.get('MUGEN_AI_PORT', '11435')}"
WHISPER_URL = os.environ.get("YURA_WHISPER_URL", "http://127.0.0.1:8178")
WHISPER_BIN = os.environ.get(
    "YURA_WHISPER_BIN",
    os.path.expanduser("~/.local/src/whisper.cpp/build/bin/whisper-server"))
WHISPER_MODEL = os.environ.get(
    "YURA_WHISPER_MODEL",
    os.path.expanduser("~/.local/share/whisper/ggml-large-v3-turbo.bin"))
STT_LANG = os.environ.get("YURA_VOICE_LANG", "ja")
VOICEVOX_URL = os.environ.get("YURA_VOICEVOX_URL", "http://127.0.0.1:50021")
VOICEVOX_SPEAKER = int(os.environ.get("YURA_VOICEVOX_SPEAKER", "14"))
TTS_SPEED = float(os.environ.get("YURA_VOICE_SPEED", "1.0"))
# Name of a bundled openWakeWord model, or a path to a custom .onnx.
WAKEWORD = os.environ.get("YURA_WAKEWORD", "hey_jarvis")
WAKE_THRESHOLD = float(os.environ.get("YURA_WAKE_THRESHOLD", "0.5"))
YURA_SHELL_QML = os.path.expanduser(
    "~/.config/quickshell/mugen-shell/yura-shell.qml")
# Live knobs (voice.enabled, voice.wakeOpens) come from the shell's
# settings.json so the Settings GUI controls the daemon without a restart.
SETTINGS_FILE = os.path.expanduser("~/.config/mugen-shell/settings.json")

_settings_cache: tuple[float, dict] = (0.0, {})


def voice_settings() -> dict:
    global _settings_cache
    try:
        mtime = os.path.getmtime(SETTINGS_FILE)
        if mtime != _settings_cache[0]:
            with open(SETTINGS_FILE) as f:
                _settings_cache = (mtime, json.load(f).get("voice", {}))
    except Exception:
        pass  # keep last good values; defaults apply on first failure
    return _settings_cache[1]

SR = 16000
CHUNK = 1280                      # 80 ms, what openWakeWord expects
PREROLL_S = 0.4                   # audio kept from before speech onset
SILENCE_END_S = 0.9               # this much trailing silence ends a turn
MAX_UTTERANCE_S = 15.0
LISTEN_TIMEOUT_S = 6.0            # wake with no speech -> give up
VAD_THRESHOLD = 0.35              # silero speech probability

log_lock = threading.Lock()


def log(tag: str, msg: str = "") -> None:
    with log_lock:
        print(f"{time.strftime('%H:%M:%S')} [{tag:<10}] {msg}", flush=True)


# Shell feedback: best-effort, the pipeline must survive without the shell.
def shell_ipc(*args: str) -> None:
    try:
        subprocess.run(
            ["qs", "-c", "mugen-shell", "ipc", "call", *args],
            capture_output=True, timeout=3)
    except Exception:
        pass


def set_thinking(on: bool) -> None:
    shell_ipc("yura", "set_thinking", "true" if on else "false")


def set_listening(on: bool) -> None:
    shell_ipc("yura", "set_listening", "true" if on else "false")


def yura_ipc(*args: str) -> None:
    # yura-shell is a separate quickshell process, addressed by -p (same
    # pattern the bar uses for toggleFrom).
    try:
        subprocess.run(
            ["qs", "-p", YURA_SHELL_QML, "ipc", "call", "yura", *args],
            capture_output=True, timeout=3)
    except Exception:
        pass


def open_panel() -> None:
    yura_ipc("open")


def beep(freq: float, dur: float = 0.12, vol: float = 0.2) -> None:
    t = np.linspace(0, dur, int(48000 * dur), dtype=np.float32)
    tone = (vol * np.sin(2 * np.pi * freq * t) * np.hanning(t.size)).astype(np.float32)
    try:
        sd.play(tone, 48000)
    except Exception:
        pass


class SileroVAD:
    """Thin wrapper over the silero_vad.onnx that openWakeWord ships."""

    def __init__(self):
        import onnxruntime as ort
        import openwakeword
        path = os.path.join(
            os.path.dirname(openwakeword.__file__), "resources", "models",
            "silero_vad.onnx")
        opts = ort.SessionOptions()
        opts.inter_op_num_threads = 1
        opts.intra_op_num_threads = 1
        self.session = ort.InferenceSession(
            path, sess_options=opts, providers=["CPUExecutionProvider"])
        self.reset()

    def reset(self) -> None:
        self._h = np.zeros((2, 1, 64), dtype=np.float32)
        self._c = np.zeros((2, 1, 64), dtype=np.float32)

    def prob(self, frame_i16: np.ndarray) -> float:
        audio = (frame_i16.astype(np.float32) / 32768.0)[None, :]
        out, self._h, self._c = self.session.run(
            None, {"input": audio, "h": self._h, "c": self._c,
                   "sr": np.array(SR, dtype=np.int64)})
        return float(out[0][-1])


def frames_to_wav(frames: list[np.ndarray]) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(np.concatenate(frames).tobytes())
    return buf.getvalue()


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
    r = requests.post(
        f"{WHISPER_URL}/inference",
        files={"file": ("speech.wav", wav, "audio/wav")},
        data={"response_format": "json", "temperature": "0.0"},
        timeout=60)
    r.raise_for_status()
    return r.json().get("text", "").strip()


class Chat:
    """Keeps one mugen-ai conversation for the whole voice session."""

    def __init__(self):
        self.conversation_id = 0

    def ask(self, text: str) -> str:
        try:
            return self._ask(text)
        except requests.HTTPError as e:
            # 400 with a bound id = the conversation was deleted from the
            # panel behind our back; start a fresh one instead of dying.
            if (self.conversation_id and e.response is not None
                    and e.response.status_code == 400):
                log("chat", "conversation gone, starting a new one")
                self.conversation_id = 0
                return self._ask(text)
            raise

    def _ask(self, text: str) -> str:
        parts: list[str] = []
        payload = {"message": text, "conversation_id": self.conversation_id}
        with requests.post(f"{AI_URL}/chat", json=payload, stream=True,
                           timeout=(5, 300)) as r:
            r.raise_for_status()
            # The SSE content-type carries no charset, so requests would
            # fall back to latin-1 and mojibake the reply.
            r.encoding = "utf-8"
            for line in r.iter_lines(decode_unicode=True):
                if not line or not line.startswith("data: "):
                    continue
                ev = json.loads(line[6:])
                if "conversation_id" in ev and not self.conversation_id:
                    self.conversation_id = ev["conversation_id"]
                    # Select it AND steer the panel there — selection alone
                    # is not broadcast, so an open panel would keep showing
                    # whatever conversation it had before.
                    requests.post(
                        f"{AI_URL}/conversations/{self.conversation_id}/select",
                        timeout=3)
                    yura_ipc("show_conversation", str(self.conversation_id))
                if "content" in ev:
                    parts.append(ev["content"])
                if "tool_confirm" in ev:
                    # Voice can't render an approval card; decline and let the
                    # model explain, the user can redo it from the panel.
                    requests.post(f"{AI_URL}/chat/confirm", json={
                        "confirm_id": ev["tool_confirm"]["confirm_id"],
                        "approved": False}, timeout=5)
                if ev.get("error"):
                    raise RuntimeError(ev["error"])
                if ev.get("done"):
                    break
        return "".join(parts)


_MD_JUNK = re.compile(r"```.*?```|`|[*_#>]|\[([^\]]*)\]\([^)]*\)", re.S)
_EMOJI = re.compile(r"[\U0001F000-\U0001FAFF☀-➿️]")


def clean_for_speech(text: str) -> str:
    text = _MD_JUNK.sub(lambda m: m.group(1) or " ", text)
    text = _EMOJI.sub("", text)
    return re.sub(r"[ \t]+", " ", text).strip()


def split_sentences(text: str) -> list[str]:
    raw = re.split(r"(?<=[。!?!?\n])", text)
    out: list[str] = []
    for s in (s.strip() for s in raw):
        if not s:
            continue
        # Glue tiny fragments to the previous sentence so TTS doesn't gasp.
        if out and len(s) < 8:
            out[-1] += s
        else:
            out.append(s)
    return out


def synthesize(sentence: str) -> bytes:
    q = requests.post(f"{VOICEVOX_URL}/audio_query",
                      params={"text": sentence, "speaker": VOICEVOX_SPEAKER},
                      timeout=10).json()
    q["speedScale"] = TTS_SPEED
    r = requests.post(f"{VOICEVOX_URL}/synthesis",
                      params={"speaker": VOICEVOX_SPEAKER}, json=q, timeout=60)
    r.raise_for_status()
    return r.content


def play_wav(data: bytes) -> None:
    with wave.open(io.BytesIO(data), "rb") as w:
        sr = w.getframerate()
        audio = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
    sd.play(audio, sr)
    sd.wait()


def speak(text: str, on_sentence=None) -> None:
    sentences = split_sentences(clean_for_speech(text))
    if not sentences:
        return
    # One-ahead synthesis pipeline: synth sentence N+1 while N plays.
    q: queue.Queue[tuple[str, bytes] | None] = queue.Queue(maxsize=2)

    def producer():
        try:
            for s in sentences:
                q.put((s, synthesize(s)))
        except Exception as e:
            log("tts", f"synthesis failed: {e}")
        finally:
            q.put(None)

    threading.Thread(target=producer, daemon=True).start()
    while (item := q.get()) is not None:
        sentence, wav = item
        if on_sentence:
            on_sentence(sentence)
        play_wav(wav)


class Daemon:
    def __init__(self):
        self.audio_q: queue.Queue[np.ndarray] = queue.Queue(maxsize=64)
        try:
            self.wake = WakeModel(wakeword_models=[WAKEWORD],
                                  inference_framework="onnx")
        except Exception:
            # First run on a fresh machine: fetch the bundled models.
            import openwakeword.utils
            openwakeword.utils.download_models()
            self.wake = WakeModel(wakeword_models=[WAKEWORD],
                                  inference_framework="onnx")
        self.wake_name = list(self.wake.models.keys())[0]
        self.vad = SileroVAD()
        self.chat = Chat()
        self.running = True
        # SIGUSR1 (the panel's mic button) starts a turn without a wake word.
        self.trigger = threading.Event()

    def _on_audio(self, indata, frames, t, status):
        if status:
            log("audio", str(status))
        try:
            self.audio_q.put_nowait(indata[:, 0].copy())
        except queue.Full:
            pass  # better to drop mic frames than to stall the stream

    def _drain(self) -> None:
        while not self.audio_q.empty():
            try:
                self.audio_q.get_nowait()
            except queue.Empty:
                break

    def _capture_utterance(self) -> list[np.ndarray] | None:
        """Collect frames until trailing silence. None = no speech at all."""
        self.vad.reset()
        frames: list[np.ndarray] = []
        preroll: list[np.ndarray] = []
        speech_started = False
        silence_run = 0.0
        started = time.time()
        frame_s = CHUNK / SR

        while self.running:
            frame = self.audio_q.get()
            p = self.vad.prob(frame)
            if not speech_started:
                preroll.append(frame)
                if len(preroll) > int(PREROLL_S / frame_s):
                    preroll.pop(0)
                if p >= VAD_THRESHOLD:
                    speech_started = True
                    frames = preroll[:]
                elif time.time() - started > LISTEN_TIMEOUT_S:
                    return None
                continue
            frames.append(frame)
            silence_run = 0.0 if p >= VAD_THRESHOLD else silence_run + frame_s
            if silence_run >= SILENCE_END_S:
                break
            if time.time() - started > MAX_UTTERANCE_S:
                break
        return frames

    def _handle_turn(self, from_button: bool = False) -> None:
        beep(880)
        set_listening(True)
        # The mic button means the user already has a Yura surface in front
        # of them — only wake-word turns open one.
        mirror_bar = False
        if not from_button:
            opens = voice_settings().get("wakeOpens", "panel")
            if opens == "panel":
                open_panel()
            elif opens == "bar":
                shell_ipc("panel", "open", "ai")
                mirror_bar = True
        # Later turns already know the conversation; land the panel on it
        # before the transcript arrives (first turn does this in Chat._ask).
        if self.chat.conversation_id:
            yura_ipc("show_conversation", str(self.chat.conversation_id))
        log("listen", "capturing...")
        frames = self._capture_utterance()
        set_listening(False)
        if not frames:
            log("listen", "no speech, back to idle")
            beep(440)
            return

        log("stt", f"{sum(f.size for f in frames) / SR:.1f}s of audio")
        wav = frames_to_wav(frames)
        try:
            text = transcribe(wav)
        except requests.ConnectionError:
            # whisper-server died (crash or stray signal); bring it back.
            log("whisper", "gone, respawning")
            self.whisper_proc = ensure_whisper_server()
            text = transcribe(wav)
        if not re.search(r"[ぁ-んァ-ヶ一-龠a-zA-Z0-9]", text):
            log("stt", f"discarded: {text!r}")
            beep(440)
            return
        log("stt", text)
        if mirror_bar:
            shell_ipc("yura", "voice_input", text)

        set_thinking(True)
        try:
            reply = self.chat.ask(text)
        finally:
            set_thinking(False)
        log("yura", reply[:120].replace("\n", " "))
        if reply:
            on_sentence = None
            if mirror_bar:
                spoken: list[str] = []

                def on_sentence(s: str) -> None:
                    spoken.append(s)
                    shell_ipc("yura", "voice_reply", "".join(spoken))
            speak(reply, on_sentence)

    def run(self) -> None:
        self.whisper_proc = ensure_whisper_server()
        log("wake", f"model={self.wake_name} threshold={WAKE_THRESHOLD}")
        try:
            while self.running:
                if not voice_settings().get("enabled", True):
                    time.sleep(2)
                    continue
                self._listen_session()
        finally:
            if self.whisper_proc:
                self.whisper_proc.terminate()

    def _listen_session(self) -> None:
        """Hold the mic until voice input gets switched off in settings."""
        with sd.InputStream(samplerate=SR, channels=1, dtype="int16",
                            blocksize=CHUNK, callback=self._on_audio):
            log("ready", "say the wake word")
            last_check = time.time()
            while self.running:
                try:
                    frame = self.audio_q.get(timeout=1)
                except queue.Empty:
                    frame = None
                from_button = False
                if self.trigger.is_set():
                    self.trigger.clear()
                    from_button = True
                    log("wake", "push-to-talk")
                elif frame is None:
                    continue
                else:
                    score = self.wake.predict(frame)[self.wake_name]
                    if score < WAKE_THRESHOLD:
                        if time.time() - last_check > 2:
                            last_check = time.time()
                            if not voice_settings().get("enabled", True):
                                log("voice", "disabled, releasing mic")
                                return
                        continue
                    log("wake", f"score={score:.2f}")
                try:
                    self._handle_turn(from_button)
                except Exception as e:
                    log("error", str(e))
                    beep(330, 0.3)
                    try:
                        speak("ごめんね、エラーで返事できなかった。")
                    except Exception:
                        pass
                self.wake.reset()
                self._drain()
                # A button press that landed mid-turn shouldn't queue another.
                self.trigger.clear()


def main() -> None:
    daemon = Daemon()

    def stop(*_):
        daemon.running = False
        os._exit(0)

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGUSR1, lambda *_: daemon.trigger.set())
    daemon.run()


if __name__ == "__main__":
    main()
