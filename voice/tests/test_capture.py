"""Capture and the fire-and-forget shell IPC, on their failure paths.

Both are about a turn that must end rather than wedge: the mic can stop
delivering mid-capture, and the UI must never be left showing the wrong state.

Run from voice/:  python -m unittest discover -s tests
"""

import os
import sys
import threading
import time
import unittest

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from yura import audio, shell  # noqa: E402
from yura.audio import Capture  # noqa: E402
from yura.const import CHUNK  # noqa: E402


class _FakeVAD:
    def __init__(self, probs):
        self.probs = list(probs)
        self.i = 0

    def reset(self):
        self.i = 0

    def prob(self, _frame):
        p = self.probs[min(self.i, len(self.probs) - 1)]
        self.i += 1
        return p


def frame(value: int) -> np.ndarray:
    return np.full(CHUNK, value, dtype=np.int16)


class DeadMic(unittest.TestCase):
    def setUp(self):
        # The real 15 s patience is deliberate, but no test should sit for it.
        self._saved = audio.MAX_UTTERANCE_S
        audio.MAX_UTTERANCE_S = 1.0

    def tearDown(self):
        audio.MAX_UTTERANCE_S = self._saved

    def test_a_mic_that_stops_delivering_ends_the_turn(self):
        # Nothing is ever queued. An unbounded get parks the thread that also
        # answers the push-to-talk key, so the whole daemon would wedge.
        cap = Capture(lambda: True, threading.Event())
        cap.vad = _FakeVAD([0.0])
        started = time.time()
        self.assertIsNone(cap.utterance(timeout=0.6))
        self.assertLess(time.time() - started, 5.0)

    def test_audio_collected_before_the_mic_died_is_kept(self):
        cap = Capture(lambda: True, threading.Event())
        cap.vad = _FakeVAD([0.9])
        for _ in range(6):
            cap.queue.put(frame(9))
        out = cap.utterance(timeout=0.6)
        self.assertTrue(out)
        self.assertTrue(np.array_equal(out[-1], frame(9)))


class IpcOrder(unittest.TestCase):
    """A stale set_speaking(false) landing last turns the stop button into a mic."""

    def test_calls_run_in_the_order_they_were_made(self):
        seen = []
        done = threading.Event()

        def fake_run(cmd, **kw):
            # Slow first call: a thread per call would land it last.
            if len(seen) == 0:
                time.sleep(0.2)
            seen.append(cmd[-1])
            if len(seen) == 12:
                done.set()

        saved = shell.subprocess.run
        shell.subprocess.run = fake_run
        try:
            expected = []
            for i in range(12):
                value = "true" if i % 2 == 0 else "false"
                expected.append(value)
                shell._ipc_async(["qs", "ipc", "call", "yura", "set_speaking", value])
            self.assertTrue(done.wait(timeout=10), f"only saw {len(seen)}")
        finally:
            shell.subprocess.run = saved
        self.assertEqual(seen, expected)


if __name__ == "__main__":
    unittest.main()
