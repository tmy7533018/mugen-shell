import os
import queue
import re
import signal
import threading
import time
from collections import deque

import numpy as np
import requests

from .audio import (
    FOLLOWUP_TIMEOUT_S,
    LISTEN_TIMEOUT_S,
    Capture,
    frames_to_wav,
)
from .chat import Chat
from .const import CHUNK, SR
from .control import ReadAloud, serve_control_socket
from .enroll import run_enrollment
from .log import log
from .messages import msg
from .settings import voice_float, voice_settings
from .shell import (
    open_panel,
    set_listening,
    set_thinking,
    shell_ipc,
    shell_ipc_read,
    yura_ipc,
)
from .shell import state as shell_state
from .sound import beep, cue
from .stt import ensure_whisper_server, transcribe
from .tts import join_spoken, speak_guarded
from .wake import (
    ENROLL_MARKER,
    WAKE_PATIENCE,
    WAKE_THRESHOLD,
    WAKE_VAD_GATE,
    WakeDetector,
    dump_wake_audio,
)


class Daemon:
    def __init__(self):
        self.running = True
        # Raised by the control socket, consumed by the wake loop between
        # frames: trigger starts a turn without a wake word, trigger_fresh does
        # the same into a new conversation, cancel drops capture (or stops
        # speech at a sentence break), enroll starts voice registration.
        self.trigger = threading.Event()
        self.trigger_fresh = threading.Event()
        self.enroll = threading.Event()
        self.cancel = threading.Event()
        self.capture = Capture(lambda: self.running, self.cancel)
        self.wake = WakeDetector()
        self.chat = Chat()
        self.read_aloud = ReadAloud()

    def request_turn(self, fresh: bool = False) -> None:
        (self.trigger_fresh if fresh else self.trigger).set()

    def request_cancel(self) -> None:
        self.cancel.set()
        self.read_aloud.stop()

    def request_enroll(self) -> None:
        # Clear now rather than in run_enrollment: the wake loop only dequeues
        # this between turns, and a cancel sent in that gap must still land.
        self.cancel.clear()
        self.enroll.set()

    def state(self) -> dict:
        return {**shell_state(),
                "enrolling": self.enroll.is_set() or os.path.exists(ENROLL_MARKER),
                "conversation_id": self.chat.conversation_id}

    def _handle_turn(self, from_button: bool = False) -> None:
        self.cancel.clear()
        # A summons outranks a message being read aloud, and the mic would
        # otherwise capture it.
        self.read_aloud.stop()
        # After a spoken reply, keep listening without the wake word. Silence,
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
            self.capture.drain()

    def _one_turn(self, open_surface: bool, follow_up: bool) -> bool:
        """One capture -> STT -> chat -> TTS round; True keeps the floor open."""
        if follow_up:
            cue("soundFollowUp", 660)
        else:
            cue("soundWake", 880)
        set_listening(True)
        try:
            # The mic button means a Yura surface is already in front of the
            # user; only first wake-word turns open one.
            if open_surface:
                opens = voice_settings().get("wakeOpens", "panel")
                if opens == "panel":
                    open_panel()
                elif opens == "bar":
                    shell_ipc("panel", "open", "ai")
            # Rotation must run before steering, or the panel would flash
            # the stale conversation this turn is about to abandon.
            self.chat.maybe_rotate()
            # Land the panel on the conversation before the transcript
            # arrives; the first turn does it in Chat._ask.
            if self.chat.conversation_id:
                yura_ipc("show_conversation", str(self.chat.conversation_id))
            log("listen", "capturing..." + (" (follow-up)" if follow_up else ""))
            frames = self.capture.utterance(
                timeout=FOLLOWUP_TIMEOUT_S if follow_up else LISTEN_TIMEOUT_S)
        finally:
            set_listening(False)
        if not frames:
            log("listen", "no speech, back to idle")
            cue("soundEnd", 440)
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
                cue("soundEnd", 440)
                return False
            log("stt", text)
            # Mirror into the Spotlight pill whenever it's on screen, however
            # the turn started.
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
        # SIGTERM exits hard (os._exit skips finally), so a kill mid-enrollment
        # leaves the marker behind and the UI would read it as still running.
        try:
            os.remove(ENROLL_MARKER)
        except OSError:
            pass
        self.whisper_proc = ensure_whisper_server()
        # Report the effective gate, not the env fallback it may be shadowing.
        log("wake", f"model={self.wake.name} "
                    f"threshold={voice_float('wakeThreshold', WAKE_THRESHOLD, 0.05, 1.0)}")
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
        with self.capture.stream():
            log("ready", "say the wake word")
            last_check = time.time()
            wake_streak = 0
            wake_ring: deque[np.ndarray] = deque(maxlen=int(2.5 / (CHUNK / SR)))
            vad_recent: deque[float] = deque(maxlen=int(1.0 / (CHUNK / SR)))
            while self.running:
                try:
                    frame = self.capture.queue.get(timeout=1)
                except queue.Empty:
                    frame = None
                if self.enroll.is_set():
                    self.enroll.clear()
                    run_enrollment(self.capture, self.cancel,
                                   lambda: self.running, self.wake.build)
                    self.wake.reset()
                    self.capture.drain()
                    continue
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
                    vad_recent.append(self.capture.vad.prob(frame))
                    score = self.wake.predict(frame)
                    # Floor above zero: a 0 threshold would wake on every frame.
                    threshold = voice_float("wakeThreshold", WAKE_THRESHOLD, 0.05, 1.0)
                    if score < threshold:
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
                    # Each wake is a fresh summons. Follow-up turns still share
                    # the conversation bound this session.
                    self.chat.reset()
                try:
                    self._handle_turn(from_button)
                except Exception as e:
                    log("error", str(e))
                    beep(330, 0.3)
                    try:
                        speak_guarded(msg("error"))
                    except Exception:
                        pass
                self.wake.reset()
                self.capture.drain()
                # A button press that landed mid-turn shouldn't queue another.
                self.trigger.clear()


def main() -> None:
    daemon = Daemon()

    def stop(*_):
        daemon.running = False
        os._exit(0)

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    serve_control_socket(daemon)
    daemon.run()
