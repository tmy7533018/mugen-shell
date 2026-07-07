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
from collections import deque
import re
import signal
import subprocess
import threading
import time
import wave

import numpy as np
import requests
import sounddevice as sd
from openwakeword.model import Model as WakeModel

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
# AivisSpeech speaks the same audio_query/synthesis API, just elsewhere.
AIVIS_URL = os.environ.get("YURA_AIVIS_URL", "http://127.0.0.1:10101")
VOICEVOX_SPEAKER = int(os.environ.get("YURA_VOICEVOX_SPEAKER", "14"))
TTS_SPEED = float(os.environ.get("YURA_VOICE_SPEED", "1.0"))
# Engines master at very different loudness (Aivis ~8 dB hotter than
# VOICEVOX); every spoken clip is RMS-normalized to this target so a
# voice change never changes the room volume.
TTS_TARGET_DBFS = float(os.environ.get("YURA_TTS_TARGET_DBFS", "-23"))
# Piper is the non-Japanese TTS path; voices are bare names resolved here.
PIPER_BIN = os.environ.get("YURA_PIPER_BIN", "piper")
PIPER_VOICES_DIR = os.path.expanduser(
    os.environ.get("YURA_PIPER_VOICES", "~/.local/share/piper/voices"))
# Name of a bundled openWakeWord model, or a path to a custom .onnx.
WAKEWORD = os.environ.get("YURA_WAKEWORD", "hey_jarvis")
WAKE_THRESHOLD = float(os.environ.get("YURA_WAKE_THRESHOLD", "0.5"))
# Consecutive frames that must clear the threshold. Real utterances hold a
# high-score plateau across several 80 ms frames; media speech grazing the
# boundary (anime dialogue especially) tends to spike on a single frame.
WAKE_PATIENCE = int(os.environ.get("YURA_WAKE_PATIENCE", "2"))
# The wake model is confidently wrong on out-of-domain mechanical noise
# (washing machines scored 0.7-0.9); a trigger only counts if the VAD saw
# something speech-like in the last second.
WAKE_VAD_GATE = float(os.environ.get("YURA_WAKE_VAD_GATE", "0.3"))
YURA_SHELL_QML = os.path.expanduser(
    "~/.config/quickshell/mugen-shell/yura-shell.qml")
# Live knobs (voice.enabled, voice.wakeOpens) come from the shell's
# settings.json so the Settings GUI controls the daemon without a restart.
SETTINGS_FILE = os.path.expanduser("~/.config/mugen-shell/settings.json")

_settings_cache: tuple[float, dict] = (0.0, {})


def _settings() -> dict:
    global _settings_cache
    try:
        mtime = os.path.getmtime(SETTINGS_FILE)
        if mtime != _settings_cache[0]:
            with open(SETTINGS_FILE) as f:
                _settings_cache = (mtime, json.load(f))
    except Exception:
        pass  # keep last good values; defaults apply on first failure
    return _settings_cache[1]


def voice_settings() -> dict:
    return _settings().get("voice", {})

SR = 16000
CHUNK = 1280                      # 80 ms, what openWakeWord expects
PREROLL_S = 0.4                   # audio kept from before speech onset
SILENCE_END_S = 0.9               # this much trailing silence ends a turn
MAX_UTTERANCE_S = 15.0
LISTEN_TIMEOUT_S = 6.0            # wake with no speech -> give up
FOLLOWUP_TIMEOUT_S = 4.0          # post-reply window before returning to idle
CONV_IDLE_ROTATE_S = float(os.environ.get("YURA_CONV_IDLE_ROTATE", "3600"))
# Every wake-word trigger archives its preceding audio: false wakes become
# retraining negatives, real ones positives. Ring-capped, ~80 KB per file.
WAKE_DUMP_DIR = os.path.expanduser("~/.local/share/mugen-shell/wake-debug")
WAKE_DUMP_KEEP = 100
VAD_THRESHOLD = 0.35              # silero speech probability

log_lock = threading.Lock()


def log(tag: str, msg: str = "") -> None:
    with log_lock:
        print(f"{time.strftime('%H:%M:%S')} [{tag:<10}] {msg}", flush=True)


# Shell feedback: best-effort and fire-and-forget — the pipeline must
# survive without the shell, and an inline qs client launch is slow enough
# to delay capture start and put audible gaps between spoken sentences.
def _ipc_async(cmd: list[str]) -> None:
    def run():
        try:
            subprocess.run(cmd, capture_output=True, timeout=3)
        except Exception:
            pass
    threading.Thread(target=run, daemon=True).start()


def shell_ipc(*args: str) -> None:
    _ipc_async(["qs", "-c", "mugen-shell", "ipc", "call", *args])


def shell_ipc_read(*args: str) -> str:
    try:
        r = subprocess.run(
            ["qs", "-c", "mugen-shell", "ipc", "call", *args],
            capture_output=True, text=True, timeout=3)
        return r.stdout.strip()
    except Exception:
        return ""


def set_thinking(on: bool) -> None:
    shell_ipc("yura", "set_thinking", "true" if on else "false")


def set_listening(on: bool) -> None:
    flag = "true" if on else "false"
    shell_ipc("yura", "set_listening", flag)
    # The panel's mic button flips to a cancel button while listening.
    yura_ipc("set_listening", flag)


def set_speaking(on: bool) -> None:
    # The bar holds its auto-close while the spoken reply is playing.
    shell_ipc("yura", "set_speaking", "true" if on else "false")


def yura_ipc(*args: str) -> None:
    # yura-shell is a separate quickshell process, addressed by -p (same
    # pattern the bar uses for toggleFrom).
    _ipc_async(["qs", "-p", YURA_SHELL_QML, "ipc", "call", "yura", *args])


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


class Chat:
    """Keeps one mugen-ai conversation, rotated after an idle gap."""

    def __init__(self):
        self.conversation_id = 0
        self.model = ""  # what the bound conversation was seeded with
        self.last_turn = 0.0

    def reset(self) -> None:
        self.conversation_id = 0
        self.model = ""

    def maybe_rotate(self, want: str | None = None) -> None:
        """Every start-a-fresh-conversation policy lives here."""
        if not self.conversation_id:
            return
        # An hour of silence usually means a new topic; a fresh conversation
        # keeps per-turn context small. Long-term memory bridges the cut.
        if time.time() - self.last_turn > CONV_IDLE_ROTATE_S:
            log("chat", "idle gap, rotating to a new conversation")
            self.reset()
            return
        # The bound model always wins on the backend, so a mid-conversation
        # change of the bar model knob would silently not apply; changing
        # models reads as "new head, new conversation". Compare against the
        # knob value this conversation was seeded with — the backend may
        # echo a normalized name.
        if want is None:
            want = _settings().get("ai", {}).get("barModel", "")
        if want and self.model and want != self.model:
            log("chat", f"model changed to {want}, rotating conversation")
            self.reset()

    def ask(self, text: str) -> str:
        # One read serves both the rotation check and the request payload,
        # so a settings write mid-turn can't split the decision.
        want = _settings().get("ai", {}).get("barModel", "")
        self.maybe_rotate(want)
        try:
            reply = self._ask(text, want)
        except requests.HTTPError as e:
            # 400 with a bound id = the conversation was deleted from the
            # panel behind our back; start a fresh one instead of dying.
            if (self.conversation_id and e.response is not None
                    and e.response.status_code == 400):
                log("chat", "conversation gone, starting a new one")
                self.reset()
                reply = self._ask(text, want)
            else:
                raise
        self.last_turn = time.time()
        return reply

    def _ask(self, text: str, model: str = "") -> str:
        parts: list[str] = []
        payload = {"message": text, "conversation_id": self.conversation_id}
        # Voice mirrors into the bar pill, so it follows the bar's model
        # knob (Settings → AI / Yura → Bar Yura model); empty falls back
        # to the backend default, exactly like the bar row does.
        if model:
            payload["model"] = model
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
                    # Seed tracking from the knob we sent; the backend echo
                    # only fills in when the knob was empty.
                    self.model = model or ev.get("model", "")
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
    # ASCII periods only count at a whitespace boundary so decimals survive.
    raw = re.split(r"(?<=[。!?!?\n])|(?<=\.)\s+", text)
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


def join_spoken(parts: list[str]) -> str:
    # Latin sentences need back the space that split_sentences consumed;
    # Japanese keeps running flush.
    out = ""
    for p in parts:
        if out and out[-1] in ".!?":
            out += " "
        out += p
    return out


def _style_id(voice: str) -> int | None:
    # Hand-edited settings must degrade to the default voice, not crash
    # the turn sentence by sentence.
    try:
        return int(voice)
    except ValueError:
        log("tts", f"bad style id {voice!r}, using default voice")
        return None


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
    # Voice knobs come from settings.json (Settings GUI, mtime-watched) so
    # a change applies from the next sentence; env vars are the fallback.
    # voice.tts is "voicevox:<style-id>" or "piper:<voice-name>"; the voice
    # choice carries the engine, no separate engine setting.
    vs = voice_settings()
    # Clamp so a hand-edited settings.json can't zero the length_scale divisor.
    speed = min(max(float(vs.get("speed", TTS_SPEED)), 0.5), 2.0)
    engine, _, voice = str(vs.get("tts", "")).partition(":")
    if engine == "piper" and voice:
        return synth_piper(voice, sentence, speed)
    sid = _style_id(voice) if voice else None
    if engine == "aivis" and sid is not None:
        return synth_voicevox(AIVIS_URL, sid, sentence, speed)
    if engine != "voicevox" or sid is None:
        sid = int(vs.get("speaker", VOICEVOX_SPEAKER))
    return synth_voicevox(VOICEVOX_URL, sid, sentence, speed)


def play_wav(data: bytes) -> None:
    with wave.open(io.BytesIO(data), "rb") as w:
        sr = w.getframerate()
        channels = w.getnchannels()
        audio = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
    if channels > 1:
        audio = audio.reshape(-1, channels)
    x = audio.astype(np.float32) / 32768.0
    rms = float(np.sqrt(np.mean(x * x)))
    if rms > 1e-4:
        # Attenuation is free; boost is capped so quiet styles (whisper
        # voices) don't get their noise floor dragged up.
        gain = min(10 ** (TTS_TARGET_DBFS / 20) / rms, 3.0)
        audio = (np.clip(x * gain, -1.0, 1.0) * 32767).astype(np.int16)
    sd.play(audio, sr)
    sd.wait()


def speak(text: str, on_sentence=None, should_stop=None) -> None:
    sentences = split_sentences(clean_for_speech(text))
    if not sentences:
        return
    # One-ahead synthesis pipeline: synth sentence N+1 while N plays.
    q: queue.Queue[tuple[str, bytes] | None] = queue.Queue(maxsize=2)
    # Set once the consumer stops draining, so the producer never parks
    # forever on a full queue (one leaked thread per cancelled reply).
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
                if done.is_set() or not put((s, synthesize(s))):
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
            play_wav(wav)
    finally:
        done.set()
        while not q.empty():
            try:
                q.get_nowait()
            except queue.Empty:
                break


def dump_wake_audio(frames, score: float) -> None:
    try:
        os.makedirs(WAKE_DUMP_DIR, exist_ok=True)
        name = time.strftime("%Y%m%d-%H%M%S") + f"-{score:.2f}.wav"
        with wave.open(os.path.join(WAKE_DUMP_DIR, name), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(np.concatenate(list(frames)).tobytes())
        for old in sorted(os.listdir(WAKE_DUMP_DIR))[:-WAKE_DUMP_KEEP]:
            os.remove(os.path.join(WAKE_DUMP_DIR, old))
    except Exception as e:
        log("dump", str(e))


def speak_guarded(text: str, on_sentence=None, should_stop=None) -> None:
    # Every audible reply must raise yuraSpeaking (the bar holds auto-close
    # on it), including the error apology.
    set_speaking(True)
    try:
        speak(text, on_sentence, should_stop=should_stop)
    finally:
        set_speaking(False)


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
        # SIGUSR1 (the panel's mic button) starts a turn without a wake word;
        # SIGUSR2 cancels the capture (or stops speech at a sentence break).
        # SIGRTMIN+1 is the mic button on an empty chat: same as SIGUSR1 but
        # into a fresh conversation instead of the running voice thread.
        self.trigger = threading.Event()
        self.trigger_fresh = threading.Event()
        self.cancel = threading.Event()

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

    def _capture_utterance(self, timeout: float = LISTEN_TIMEOUT_S) -> list[np.ndarray] | None:
        """Collect frames until trailing silence. None = no speech at all."""
        self.vad.reset()
        frames: list[np.ndarray] = []
        preroll: list[np.ndarray] = []
        speech_started = False
        silence_run = 0.0
        started = time.time()
        frame_s = CHUNK / SR
        # The confirmation beep rides the first frames of capture; a pure
        # tone can cross the VAD threshold on lucky frame alignment, so
        # onset detection holds until it has passed (frames still preroll).
        beep_guard = int(0.25 / frame_s)
        seen = 0

        while self.running:
            if self.cancel.is_set():
                log("listen", "cancelled")
                return None
            frame = self.audio_q.get()
            p = self.vad.prob(frame)
            seen += 1
            if not speech_started:
                preroll.append(frame)
                if len(preroll) > int(PREROLL_S / frame_s):
                    preroll.pop(0)
                if p >= VAD_THRESHOLD and seen > beep_guard:
                    speech_started = True
                    frames = preroll[:]
                elif time.time() - started > timeout:
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
        self.cancel.clear()
        # Follow-up mode: after a spoken reply, keep listening without the
        # wake word so the exchange flows like a conversation. Silence,
        # cancel, or an empty turn drops back to idle.
        first = True
        while self.running and not self.cancel.is_set():
            spoke = self._one_turn(open_surface=first and not from_button,
                                   follow_up=not first)
            if not spoke or not voice_settings().get("followUp", True):
                break
            first = False
            # TTS ran for a while; stale mic backlog (echo residue, room
            # noise) must not become the follow-up utterance.
            self._drain()

    def _one_turn(self, open_surface: bool, follow_up: bool) -> bool:
        """One capture -> STT -> chat -> TTS round; True keeps the floor open."""
        beep(660 if follow_up else 880)
        set_listening(True)
        try:
            # The mic button means the user already has a Yura surface in
            # front of them — only first wake-word turns open one.
            if open_surface:
                opens = voice_settings().get("wakeOpens", "panel")
                if opens == "panel":
                    open_panel()
                elif opens == "bar":
                    shell_ipc("panel", "open", "ai")
            # Rotation must run before steering, or the panel would flash
            # the stale conversation this turn is about to abandon.
            self.chat.maybe_rotate()
            # Later turns already know the conversation; land the panel on
            # it before the transcript arrives (first turn: Chat._ask).
            if self.chat.conversation_id:
                yura_ipc("show_conversation", str(self.chat.conversation_id))
            log("listen", "capturing..." + (" (follow-up)" if follow_up else ""))
            frames = self._capture_utterance(
                timeout=FOLLOWUP_TIMEOUT_S if follow_up else LISTEN_TIMEOUT_S)
        finally:
            set_listening(False)
        if not frames:
            log("listen", "no speech, back to idle")
            beep(440)
            return False

        log("stt", f"{sum(f.size for f in frames) / SR:.1f}s of audio")
        wav = frames_to_wav(frames)
        # Thinking spans STT too: a whisper respawn can outlast the bar's
        # auto-close interval, which would otherwise fire in this gap.
        set_thinking(True)
        try:
            try:
                text = transcribe(wav)
            except requests.RequestException:
                # whisper-server died or wedged mid-request (mid-body death is
                # ChunkedEncodingError, not ConnectionError); bring it back.
                log("whisper", "gone, respawning")
                proc = ensure_whisper_server()
                if proc:
                    self.whisper_proc = proc
                text = transcribe(wav)
            if not re.search(r"[ぁ-んァ-ヶ一-龠a-zA-Z0-9]", text):
                log("stt", f"discarded: {text!r}")
                beep(440)
                return False
            log("stt", text)
            # Mirror into the Spotlight pill whenever it's on screen, however
            # the turn started (wake word, panel button, or the bar's own).
            mirror_bar = shell_ipc_read("panel", "current") == "ai"
            if mirror_bar:
                shell_ipc("yura", "voice_input", text)
            reply = self.chat.ask(text)
        finally:
            set_thinking(False)
        if not reply:
            return False
        log("yura", reply[:120].replace("\n", " "))
        on_sentence = None
        if mirror_bar:
            spoken: list[str] = []

            def on_sentence(s: str) -> None:
                spoken.append(s)
                shell_ipc("yura", "voice_reply", join_spoken(spoken))
        speak_guarded(reply, on_sentence, should_stop=self.cancel.is_set)
        return not self.cancel.is_set()

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
            wake_streak = 0
            wake_ring: deque[np.ndarray] = deque(maxlen=int(2.5 / (CHUNK / SR)))
            vad_recent: deque[float] = deque(maxlen=int(1.0 / (CHUNK / SR)))
            while self.running:
                try:
                    frame = self.audio_q.get(timeout=1)
                except queue.Empty:
                    frame = None
                from_button = False
                if self.trigger_fresh.is_set():
                    self.trigger_fresh.clear()
                    self.trigger.clear()
                    from_button = True
                    self.chat.reset()
                    log("wake", "push-to-talk (new chat)")
                elif self.trigger.is_set():
                    self.trigger.clear()
                    from_button = True
                    log("wake", "push-to-talk")
                elif frame is None:
                    continue
                else:
                    wake_ring.append(frame)
                    vad_recent.append(self.vad.prob(frame))
                    score = self.wake.predict(frame)[self.wake_name]
                    if score < WAKE_THRESHOLD:
                        wake_streak = 0
                        if time.time() - last_check > 2:
                            last_check = time.time()
                            if not voice_settings().get("enabled", True):
                                log("voice", "disabled, releasing mic")
                                return
                        continue
                    wake_streak += 1
                    if wake_streak < WAKE_PATIENCE:
                        continue
                    wake_streak = 0
                    if max(vad_recent, default=0.0) < WAKE_VAD_GATE:
                        log("wake", f"gated: score={score:.2f} vad={max(vad_recent, default=0.0):.2f}")
                        dump_wake_audio(wake_ring, score)
                        continue
                    log("wake", f"score={score:.2f}")
                    dump_wake_audio(wake_ring, score)
                try:
                    self._handle_turn(from_button)
                except Exception as e:
                    log("error", str(e))
                    beep(330, 0.3)
                    try:
                        speak_guarded("ごめんね、エラーで返事できなかった。")
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
    signal.signal(signal.SIGUSR2, lambda *_: daemon.cancel.set())
    signal.signal(signal.SIGRTMIN + 1, lambda *_: daemon.trigger_fresh.set())
    daemon.run()


if __name__ == "__main__":
    main()
