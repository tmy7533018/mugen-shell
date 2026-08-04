"""Two speakers must not share the output stream at the same time.

Run from voice/:  python -m unittest discover -s tests
"""

import os
import sys
import threading
import time
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from yura.tts import player  # noqa: E402


class PlaybackSerialisation(unittest.TestCase):
    def setUp(self):
        self._speak = player.speak
        self._set_speaking = player.set_speaking
        player.set_speaking = lambda _v: None
        self.intervals = []
        self.lock = threading.Lock()

        def fake_speak(text, on_sentence=None, should_stop=None, voice=None):
            start = time.monotonic()
            time.sleep(0.15)
            with self.lock:
                self.intervals.append((start, time.monotonic(), text))

        player.speak = fake_speak

    def tearDown(self):
        player.speak = self._speak
        player.set_speaking = self._set_speaking

    def _run_both(self):
        threads = [
            threading.Thread(target=player.speak_guarded, args=(name,))
            for name in ("reply", "read-aloud")
        ]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

    def test_the_two_playbacks_do_not_overlap(self):
        self._run_both()
        self.assertEqual(len(self.intervals), 2)
        first, second = sorted(self.intervals, key=lambda i: i[0])
        self.assertLessEqual(
            first[1], second[0] + 1e-3,
            f"{first[2]!r} was still playing when {second[2]!r} started",
        )

    def test_both_still_get_their_turn(self):
        self._run_both()
        self.assertEqual({i[2] for i in self.intervals}, {"reply", "read-aloud"})
