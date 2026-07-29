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


def wake_word_on() -> bool:
    return bool(voice_settings().get("wakeWord", False))


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
        self.ptt_held = threading.Event()
        self.ptt_turn = threading.Event()
        # Set alongside whichever of the above was raised. The wake loop polls
        # between frames, but the idle loop has no frames to wake it up.
        self.summons = threading.Event()
        self.capture = Capture(lambda: self.running, self.cancel)
        self.wake: WakeDetector | None = None
        self._wake_failed = False
        self.chat = Chat()
        self.read_aloud = ReadAloud()

    def request_turn(self, fresh: bool = False) -> None:
        (self.trigger_fresh if fresh else self.trigger).set()
        self.summons.set()

    def _trigger_name(self) -> str:
        return "ptt key" if self.ptt_turn.is_set() else "mic button"

    def request_ptt(self, down: bool) -> None:
        if down:
            self.ptt_held.set()
            self.ptt_turn.set()
            self.request_turn(fresh=True)
        else:
            self.ptt_held.clear()

    def request_cancel(self) -> None:
        self.cancel.set()
        self.read_aloud.stop()

    def request_enroll(self) -> None:
        # Clear now rather than in run_enrollment: the wake loop only dequeues
        # this between turns, and a cancel sent in that gap must still land.
        self.cancel.clear()
        self.enroll.set()
        self.summons.set()

    def state(self) -> dict:
        return {**shell_state(),
                "enrolling": self.enroll.is_set() or os.path.exists(ENROLL_MARKER),
                "conversation_id": self.chat.conversation_id}

    def _handle_turn(self, surface_up: bool = False) -> None:
        self.cancel.clear()
        # A summons outranks a message being read aloud, and the mic would
        # otherwise capture it.
        self.read_aloud.stop()
        # After a spoken reply, keep listening without the wake word. Silence,
        # cancel, or an empty turn drops back to idle.
        first = True
        while self.running and not self.cancel.is_set():
            spoke = self._one_turn(open_surface=first and not surface_up,
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
                timeout=FOLLOWUP_TIMEOUT_S if follow_up else LISTEN_TIMEOUT_S,
                held=self.ptt_held.is_set if not follow_up else None)
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
        try:
            while self.running:
                if not voice_settings().get("enabled", True):
                    time.sleep(2)
                    continue
                if self._wake_ready():
                    self._wake_session()
                else:
                    self._idle_session()
        finally:
            if self.whisper_proc:
                self.whisper_proc.terminate()

    def _wake_ready(self) -> bool:
        """Whether the wake loop should own the mic rather than the idle loop."""
        if not wake_word_on():
            return False
        if self.wake is None and not self._wake_failed:
            try:
                self.wake = WakeDetector()
            except Exception as e:
                # A build with the wake word left out has no openWakeWord to
                # import. Push-to-talk is the point of that build, so say so
                # once and stay in the idle loop instead of retrying forever.
                self._wake_failed = True
                log("wake", f"unavailable, push-to-talk only: {e}")
                return False
            # Report the effective gate, not the env fallback it may shadow.
            log("wake", f"model={self.wake.name} "
                        f"threshold={voice_float('wakeThreshold', WAKE_THRESHOLD, 0.05, 1.0)}")
        return self.wake is not None

    def _take_trigger(self) -> bool:
        """Consume a pending trigger. True means the surface is already up."""
        fresh = self.trigger_fresh.is_set()
        self.trigger_fresh.clear()
        self.trigger.clear()
        if fresh:
            self.chat.reset()
        log("wake", self._trigger_name() + (" (new chat)" if fresh else ""))
        return not self.ptt_turn.is_set()

    def _run_turn(self, surface_up: bool) -> None:
        try:
            self._handle_turn(surface_up)
        except Exception as e:
            log("error", str(e))
            beep(330, 0.3)
            try:
                speak_guarded(msg("error"))
            except Exception:
                pass
        if self.wake is not None:
            self.wake.reset()
        self.capture.drain()
        # A button press that landed mid-turn shouldn't queue another.
        self.trigger.clear()
        self.trigger_fresh.clear()
        self.ptt_held.clear()
        self.ptt_turn.clear()
        self.summons.clear()

    def _idle_session(self) -> None:
        """Wait with the mic released; only a key or button starts a turn.

        The stream opens per turn instead of being held. That costs ~90 ms
        before the first frame, well inside the 300 ms that separates a
        push-to-talk hold from a tap.
        """
        log("ready", "push to talk")
        while self.running:
            if not self.summons.wait(1.0):
                if not voice_settings().get("enabled", True) or self._wake_ready():
                    return
                continue
            self.summons.clear()
            if self.enroll.is_set():
                self.enroll.clear()
                log("enroll", "wake word is off, nothing to enrol against")
                continue
            surface_up = self._take_trigger()
            self.capture.prewarm()
            with self.capture.stream():
                self._run_turn(surface_up)

    def _wake_session(self) -> None:
        """Hold the mic and score every frame until the wake word goes off."""
        wake = self.wake
        self.capture.prewarm()
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
                                   lambda: self.running, wake.build)
                    wake.reset()
                    self.capture.drain()
                    continue
                surface_up = False
                if self.trigger_fresh.is_set() or self.trigger.is_set():
                    surface_up = self._take_trigger()
                elif frame is None:
                    continue
                else:
                    wake_ring.append(frame)
                    vad_recent.append(self.capture.vad.prob(frame))
                    score = wake.predict(frame)
                    # Floor above zero: a 0 threshold would wake on every frame.
                    threshold = voice_float("wakeThreshold", WAKE_THRESHOLD, 0.05, 1.0)
                    if score < threshold:
                        wake_streak = 0
                        if time.time() - last_check > 2:
                            last_check = time.time()
                            if not voice_settings().get("enabled", True):
                                log("voice", "disabled, releasing mic")
                                return
                            if not wake_word_on():
                                log("wake", "switched off, releasing mic")
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
                self._run_turn(surface_up)


def main() -> None:
    daemon = Daemon()

    def stop(*_):
        daemon.running = False
        os._exit(0)

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    serve_control_socket(daemon)
    daemon.run()
