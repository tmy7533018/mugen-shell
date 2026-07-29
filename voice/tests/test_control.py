"""The request_* methods the control socket drives, and the state it reports.

Run from voice/:  python -m unittest discover -s tests
"""

import os
import sys
import threading
import types
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from yura import settings, shell  # noqa: E402
from yura.daemon import Daemon, wake_word_on  # noqa: E402


class _FakeReadAloud:
    def __init__(self):
        self.stops = 0

    def stop(self):
        self.stops += 1


class _FakeChat:
    conversation_id = 0

    def reset(self):
        self.conversation_id = 0


def bare_daemon() -> Daemon:
    """A Daemon with only the parts the control surface touches.

    Skipping __init__ keeps the wake and VAD models out of a test that is
    purely about flag handling.
    """
    d = Daemon.__new__(Daemon)
    d.running = True
    d.trigger = threading.Event()
    d.trigger_fresh = threading.Event()
    d.enroll = threading.Event()
    d.cancel = threading.Event()
    d.ptt_held = threading.Event()
    d.ptt_turn = threading.Event()
    d.summons = threading.Event()
    d.wake = None
    d._wake_failed = False
    d.read_aloud = _FakeReadAloud()
    d.chat = _FakeChat()
    return d


class _Settings:
    """Swap settings.json for a literal dict, cache and all."""

    def __init__(self, voice: dict):
        self.voice = voice

    def __enter__(self):
        self._saved = (settings._settings_cache, settings.SETTINGS_FILE)
        # A missing path makes settings() keep the cache instead of reading the
        # developer's real file over the top of it.
        settings.SETTINGS_FILE = "/nonexistent/mugen-shell/settings.json"
        settings._settings_cache = (0.0, {"voice": self.voice})
        return self

    def __exit__(self, *exc):
        settings._settings_cache, settings.SETTINGS_FILE = self._saved


class RequestTurn(unittest.TestCase):
    def test_plain_turn_sets_only_trigger(self):
        d = bare_daemon()
        d.request_turn(False)
        self.assertTrue(d.trigger.is_set())
        self.assertFalse(d.trigger_fresh.is_set())

    def test_fresh_turn_sets_only_trigger_fresh(self):
        d = bare_daemon()
        d.request_turn(True)
        self.assertTrue(d.trigger_fresh.is_set())
        self.assertFalse(d.trigger.is_set())

    def test_defaults_to_the_bound_conversation(self):
        d = bare_daemon()
        d.request_turn()
        self.assertTrue(d.trigger.is_set())


class Summons(unittest.TestCase):
    """The idle loop has no audio frames to wake it, so it waits on this."""

    def test_a_turn_raises_it(self):
        d = bare_daemon()
        d.request_turn()
        self.assertTrue(d.summons.is_set())

    def test_an_enrollment_raises_it(self):
        d = bare_daemon()
        d.request_enroll()
        self.assertTrue(d.summons.is_set())

    def test_a_ptt_press_raises_it_and_a_release_does_not(self):
        d = bare_daemon()
        d.request_ptt(True)
        self.assertTrue(d.summons.is_set())
        d.summons.clear()
        d.request_ptt(False)
        self.assertFalse(d.summons.is_set())

    def test_finishing_a_turn_clears_every_trigger(self):
        d = bare_daemon()
        d._handle_turn = lambda surface_up=False: None
        d.capture = types.SimpleNamespace(drain=lambda: None)
        d.request_ptt(True)
        d._run_turn(False)
        for flag in ("trigger", "trigger_fresh", "ptt_held", "ptt_turn", "summons"):
            self.assertFalse(getattr(d, flag).is_set(), flag)


class TakeTrigger(unittest.TestCase):
    def test_a_fresh_trigger_starts_a_new_conversation(self):
        d = bare_daemon()
        d.chat = types.SimpleNamespace(reset=lambda: setattr(d, "_reset", True))
        d._reset = False
        d.request_turn(fresh=True)
        d._take_trigger()
        self.assertTrue(d._reset)
        self.assertFalse(d.trigger_fresh.is_set())

    def test_a_ptt_turn_wants_the_surface_opened(self):
        # surface_up False means _handle_turn still has to open the panel.
        d = bare_daemon()
        d.request_ptt(True)
        self.assertFalse(d._take_trigger())

    def test_a_mic_button_turn_leaves_the_surface_alone(self):
        d = bare_daemon()
        d.request_turn()
        self.assertTrue(d._take_trigger())


class WakeReady(unittest.TestCase):
    def test_off_by_default(self):
        with _Settings({}):
            self.assertFalse(wake_word_on())

    def test_follows_the_setting(self):
        with _Settings({"wakeWord": True}):
            self.assertTrue(wake_word_on())

    def test_the_idle_loop_owns_the_mic_while_the_setting_is_off(self):
        d = bare_daemon()
        with _Settings({"wakeWord": False}):
            self.assertFalse(d._wake_ready())
        self.assertIsNone(d.wake)

    def test_a_build_without_openwakeword_gives_up_once(self):
        # Retrying every second would spin the idle loop and flood the log.
        d = bare_daemon()
        calls = []

        def boom():
            calls.append(1)
            raise ModuleNotFoundError("No module named 'openwakeword'")

        with _Settings({"wakeWord": True}):
            import yura.daemon as mod
            saved, mod.WakeDetector = mod.WakeDetector, boom
            try:
                self.assertFalse(d._wake_ready())
                self.assertFalse(d._wake_ready())
            finally:
                mod.WakeDetector = saved
        self.assertEqual(len(calls), 1)


class RequestCancel(unittest.TestCase):
    def test_raises_cancel_and_silences_read_aloud(self):
        d = bare_daemon()
        d.request_cancel()
        self.assertTrue(d.cancel.is_set())
        self.assertEqual(d.read_aloud.stops, 1)


class RequestEnroll(unittest.TestCase):
    def test_clears_a_stale_cancel(self):
        # A cancel left over from the previous turn would abort the enrollment
        # the instant the wake loop dequeued it.
        d = bare_daemon()
        d.cancel.set()
        d.request_enroll()
        self.assertTrue(d.enroll.is_set())
        self.assertFalse(d.cancel.is_set())


class State(unittest.TestCase):
    def setUp(self):
        self._saved = shell.state()

    def tearDown(self):
        for k, v in self._saved.items():
            shell._record(k, v)

    def test_reports_the_broadcast_flags(self):
        d = bare_daemon()
        shell._record("listening", True)
        shell._record("speaking", False)
        s = d.state()
        self.assertTrue(s["listening"])
        self.assertFalse(s["speaking"])

    def test_reports_the_bound_conversation(self):
        d = bare_daemon()
        d.chat.conversation_id = 42
        self.assertEqual(d.state()["conversation_id"], 42)

    def test_a_queued_enrollment_counts_as_enrolling(self):
        # The marker file only appears once the wake loop picks the request up,
        # so the pending flag has to count too or the UI misses the gap.
        d = bare_daemon()
        self.assertFalse(d.state()["enrolling"])
        d.request_enroll()
        self.assertTrue(d.state()["enrolling"])


if __name__ == "__main__":
    unittest.main()
