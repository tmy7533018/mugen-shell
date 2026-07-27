"""The request_* methods the control socket drives, and the state it reports.

Run from voice/:  python -m unittest discover -s tests
"""

import os
import sys
import threading
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from yura import shell  # noqa: E402
from yura.daemon import Daemon  # noqa: E402


class _FakeReadAloud:
    def __init__(self):
        self.stops = 0

    def stop(self):
        self.stops += 1


class _FakeChat:
    conversation_id = 0


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
    d.read_aloud = _FakeReadAloud()
    d.chat = _FakeChat()
    return d


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
