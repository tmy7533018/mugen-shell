import os
import re
import signal
import threading
import time

import requests

from .audio import (
    FOLLOWUP_TIMEOUT_S,
    LISTEN_TIMEOUT_S,
    Capture,
    SileroVAD,
    frames_to_wav,
)
from .barge import BargeMonitor, NullMonitor, enabled as barge_enabled
from .chat import Chat
from .const import SR
from .control import ReadAloud, serve_control_socket
from .log import log
from .messages import msg
from .settings import voice_settings
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
from .tts import join_spoken, prewarm_tts, speak_guarded


class Daemon:
    def __init__(self):
        self.running = True
        # Raised by the control socket, consumed by the idle loop between
        # turns: trigger starts a turn, trigger_fresh does the same into a new
        # conversation, cancel drops capture (or stops speech at a sentence
        # break).
        self.trigger = threading.Event()
        self.trigger_fresh = threading.Event()
        self.cancel = threading.Event()
        self.ptt_held = threading.Event()
        self.ptt_turn = threading.Event()
        self.summons = threading.Event()
        self.capture = Capture(lambda: self.running, self.cancel)
        self.chat = Chat()
        self.read_aloud = ReadAloud()
        # Its own VAD: sharing capture's would tangle the two streams' state.
        self._barge_vad = SileroVAD()
        # Audio a barge-in cut in with, waiting to become the next utterance.
        self._barge_seed: list | None = None

    def request_turn(self, fresh: bool = False) -> None:
        (self.trigger_fresh if fresh else self.trigger).set()
        self.summons.set()

    def _trigger_name(self) -> str:
        return "ptt key" if self.ptt_turn.is_set() else "mic button"

    def request_ptt(self, down: bool, fresh: bool = False) -> None:
        if down:
            self.ptt_held.set()
            self.ptt_turn.set()
            self.request_turn(fresh=fresh)
        else:
            self.ptt_held.clear()

    def request_cancel(self) -> None:
        self.cancel.set()
        self.read_aloud.stop()

    def state(self) -> dict:
        return {**shell_state(),
                "conversation_id": self.chat.conversation_id}

    def _handle_turn(self, surface_up: bool = False) -> None:
        prewarm_tts()
        self.cancel.clear()
        # A cancel lands between the barge monitor firing and the loop reading
        # its audio, so a summons must not inherit the last turn's leftovers.
        self._barge_seed = None
        # A summons outranks a message being read aloud, and the mic would
        # otherwise capture it.
        self.read_aloud.stop()
        # After a spoken reply, keep listening without a new trigger. Silence,
        # cancel, or an empty turn drops back to idle.
        first = True
        while self.running and not self.cancel.is_set():
            spoke = self._one_turn(open_surface=first and not surface_up,
                                   follow_up=not first)
            # Talking over Yura is itself a request to keep going, whatever
            # the follow-up setting says, and the audio is already in hand.
            # A cancel still wins: the loop condition is checked first.
            if self._barge_seed and not self.cancel.is_set():
                first = False
                continue
            if not spoke or not voice_settings().get("followUp", True):
                break
            first = False
            # TTS ran for a while; stale mic backlog (echo residue, room
            # noise) must not become the follow-up utterance.
            self.capture.drain()

    def _one_turn(self, open_surface: bool, follow_up: bool) -> bool:
        """One capture -> STT -> chat -> TTS round; True keeps the floor open."""
        # A barge-in already has the user's words; a cue here would land on top
        # of them and the surface is open from the turn being interrupted.
        seed = self._barge_seed
        self._barge_seed = None
        if seed:
            pass
        elif follow_up:
            cue("soundFollowUp", 660)
        else:
            cue("soundWake", 880)
        set_listening(True)
        try:
            if open_surface:
                # wakeOpens is the pre-retirement name, still in any
                # settings.json the shell has not rewritten yet.
                opens = voice_settings().get(
                    "turnOpens", voice_settings().get("wakeOpens", "panel"))
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
            log("listen", "capturing..." + (" (barge-in)" if seed
                                            else " (follow-up)" if follow_up else ""))
            frames = self.capture.utterance(
                timeout=FOLLOWUP_TIMEOUT_S if follow_up else LISTEN_TIMEOUT_S,
                held=self.ptt_held.is_set if not follow_up else None,
                seed=seed)
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
        spoken: list[str] = []

        def on_sentence(s: str) -> None:
            spoken.append(s)
            shell_ipc("yura", "voice_reply", join_spoken(spoken))

        # The mic keeps running through playback so the user can cut in; the
        # monitor consumes those frames, which also keeps the echo residue out
        # of whatever capture comes next.
        monitor = (BargeMonitor(self.capture, self._barge_vad)
                   if barge_enabled() else NullMonitor())
        monitor.start()
        try:
            speak_guarded(reply, on_sentence if mirror_bar else None,
                          should_stop=lambda: (self.cancel.is_set()
                                               or monitor.triggered))
        finally:
            self._barge_seed = monitor.stop()
        return not self.cancel.is_set()

    def run(self) -> None:
        self.whisper_proc = ensure_whisper_server()
        try:
            while self.running:
                if not voice_settings().get("enabled", True):
                    time.sleep(2)
                    continue
                self._idle_session()
        finally:
            if self.whisper_proc:
                self.whisper_proc.terminate()

    def _take_trigger(self) -> bool:
        fresh = self.trigger_fresh.is_set()
        self.trigger_fresh.clear()
        self.trigger.clear()
        if fresh:
            self.chat.reset()
        log("turn", self._trigger_name() + (" (new chat)" if fresh else ""))
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
        self.capture.drain()
        self.trigger.clear()
        self.trigger_fresh.clear()
        self.ptt_held.clear()
        self.ptt_turn.clear()
        self.summons.clear()

    def _idle_session(self) -> None:
        log("ready", "push to talk")
        while self.running:
            if not self.summons.wait(1.0):
                if not voice_settings().get("enabled", True):
                    return
                continue
            self.summons.clear()
            surface_up = self._take_trigger()
            self.capture.prewarm()
            with self.capture.stream():
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
