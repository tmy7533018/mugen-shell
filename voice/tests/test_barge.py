"""Barge-in: when talking over a reply counts, and what survives the handover.

Driven with a fake VAD and hand-fed frames, so the thresholds are exercised
without a microphone.

Run from voice/:  python -m unittest discover -s tests
"""

import os
import queue
import sys
import time
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np  # noqa: E402

from yura import barge, settings  # noqa: E402
from yura.audio import Capture  # noqa: E402
from yura.const import CHUNK, SR  # noqa: E402

FRAME_S = CHUNK / SR


class _FakeVAD:
    """Returns a scripted probability per frame, then holds the last value."""

    def __init__(self, script):
        self.script = list(script)
        self.i = 0

    def reset(self):
        self.i = 0

    def prob(self, frame):
        if self.i < len(self.script):
            p = self.script[self.i]
        else:
            p = self.script[-1] if self.script else 0.0
        self.i += 1
        return p


class _FakeCapture:
    def __init__(self):
        self.queue = queue.Queue()


def frame(value: int = 1) -> np.ndarray:
    return np.full(CHUNK, value, dtype=np.int16)


def run_monitor(script, frames, wait=2.0):
    cap = _FakeCapture()
    m = barge.BargeMonitor(cap, _FakeVAD(script))
    m.start()
    for i in range(frames):
        cap.queue.put(frame(i + 1))
    deadline = time.time() + wait
    while time.time() < deadline and not m.triggered and not cap.queue.empty():
        time.sleep(0.01)
    time.sleep(0.05)
    seed = m.stop()
    return m, seed


class Triggering(unittest.TestCase):
    def setUp(self):
        self._saved = (settings._settings_cache, settings.SETTINGS_FILE)
        settings.SETTINGS_FILE = "/nonexistent"
        settings._settings_cache = (0.0, {"voice": {}})

    def tearDown(self):
        settings._settings_cache, settings.SETTINGS_FILE = self._saved

    def test_sustained_speech_triggers(self):
        need = int(barge.BARGE_HOLD_S / FRAME_S) + 2
        m, seed = run_monitor([0.9] * need, need)
        self.assertTrue(m.triggered)
        self.assertTrue(seed)

    def test_a_brief_spike_does_not(self):
        # A cough is loud but short; it used to be indistinguishable from
        # someone starting to talk.
        need = int(barge.BARGE_HOLD_S / FRAME_S)
        script = [0.9] * max(need - 2, 1) + [0.0] * 10
        m, seed = run_monitor(script, len(script))
        self.assertFalse(m.triggered)
        self.assertIsNone(seed)

    def test_quiet_room_does_not(self):
        m, seed = run_monitor([0.1] * 40, 40)
        self.assertFalse(m.triggered)
        self.assertIsNone(seed)

    def test_run_resets_between_bursts(self):
        # Two sub-threshold bursts must not add up to one trigger.
        need = int(barge.BARGE_HOLD_S / FRAME_S)
        half = max(need // 2, 1)
        script = ([0.9] * half + [0.0] * 4) * 2
        m, _ = run_monitor(script, len(script))
        self.assertFalse(m.triggered)

    def test_seed_holds_the_interrupting_audio(self):
        need = int(barge.BARGE_HOLD_S / FRAME_S) + 2
        m, seed = run_monitor([0.9] * need, need)
        self.assertTrue(m.triggered)
        # Capped by the preroll window, and never empty — the words the user
        # cut in with are what the next capture is built from.
        self.assertGreater(len(seed), 0)
        self.assertLessEqual(len(seed), int(barge.BARGE_PREROLL_S / FRAME_S))


class Threshold(unittest.TestCase):
    def setUp(self):
        self._saved = (settings._settings_cache, settings.SETTINGS_FILE)
        settings.SETTINGS_FILE = "/nonexistent"

    def tearDown(self):
        settings._settings_cache, settings.SETTINGS_FILE = self._saved

    def test_barge_threshold_sits_above_capture(self):
        from yura.audio import VAD_THRESHOLD
        self.assertGreater(barge.BARGE_VAD_THRESHOLD, VAD_THRESHOLD)

    def test_enabled_is_off_unless_asked_for(self):
        settings._settings_cache = (0.0, {"voice": {}})
        self.assertFalse(barge.enabled())
        settings._settings_cache = (0.0, {"voice": {"bargeIn": True}})
        self.assertTrue(barge.enabled())


class Handover(unittest.TestCase):
    """Seeded capture must treat the audio as speech already under way."""

    def test_seed_becomes_the_start_of_the_utterance(self):
        import threading
        cancel = threading.Event()
        cap = Capture(lambda: True, cancel)
        cap.vad = _FakeVAD([0.0] * 200)  # nothing but silence from here on
        seed = [frame(7), frame(8)]
        for _ in range(int(1.2 / FRAME_S)):
            cap.queue.put(frame(0))
        out = cap.utterance(timeout=5.0, seed=seed)
        self.assertIsNotNone(out)
        # Onset is not re-detected: the seed frames lead, and trailing silence
        # ends the turn as usual.
        self.assertTrue(np.array_equal(out[0], seed[0]))
        self.assertTrue(np.array_equal(out[1], seed[1]))
        self.assertGreater(len(out), len(seed))

    def test_without_a_seed_silence_still_yields_nothing(self):
        import threading
        cancel = threading.Event()
        cap = Capture(lambda: True, cancel)
        cap.vad = _FakeVAD([0.0] * 400)
        # Fed at roughly frame rate so the wall-clock timeout is what ends it,
        # the way a silent room does.
        stop = threading.Event()

        def feed():
            while not stop.is_set():
                cap.queue.put(frame(0))
                time.sleep(FRAME_S)

        t = threading.Thread(target=feed, daemon=True)
        t.start()
        try:
            self.assertIsNone(cap.utterance(timeout=0.4))
        finally:
            stop.set()
            t.join(timeout=1.0)

    def test_a_dead_mic_ends_the_turn(self):
        # Nothing is ever queued: without a bounded wait this parks forever.
        import threading
        cancel = threading.Event()
        cap = Capture(lambda: True, cancel)
        cap.vad = _FakeVAD([0.0])
        started = time.time()
        self.assertIsNone(cap.utterance(timeout=0.6))
        self.assertLess(time.time() - started, 25.0)


class NullMonitor(unittest.TestCase):
    def test_is_inert(self):
        m = barge.NullMonitor()
        m.start()
        self.assertFalse(m.triggered)
        self.assertIsNone(m.stop())


if __name__ == "__main__":
    unittest.main()
