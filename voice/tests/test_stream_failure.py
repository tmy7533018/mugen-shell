"""A reply that dies mid-stream must reach the caller, not end the turn in silence.

Run from voice/:  python -m unittest discover -s tests
"""

import os
import sys
import threading
import time
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from yura.tts import player  # noqa: E402


class StreamFailure(unittest.TestCase):
    def setUp(self):
        self._synthesize = player.synthesize
        self._play_wav = player.play_wav
        player.synthesize = lambda sentence, voice: b""
        player.play_wav = lambda data, should_stop=None: None
        self.spoken = []

    def tearDown(self):
        player.synthesize = self._synthesize
        player.play_wav = self._play_wav

    def _speak(self, sentences):
        player.speak(sentences, self.spoken.append, voice="stub")

    def test_a_mid_stream_error_reaches_the_caller(self):
        def sentences():
            yield "made it this far"
            raise RuntimeError("backend died")

        with self.assertRaises(RuntimeError):
            self._speak(sentences())
        self.assertEqual(self.spoken, ["made it this far"])

    def test_a_clean_stream_still_returns(self):
        self._speak(iter(["one", "two"]))
        self.assertEqual(self.spoken, ["one", "two"])

    def test_a_stop_is_not_reported_as_a_failure(self):
        player.speak(iter(["one", "two"]), self.spoken.append,
                     should_stop=lambda: True, voice="stub")
        self.assertEqual(self.spoken, [])

    def test_a_stop_lands_while_the_next_sentence_is_still_generating(self):
        stalled = threading.Event()
        cancelled = threading.Event()

        def sentences():
            yield "first"
            stalled.wait(5)

        def on_sentence(sentence):
            self.spoken.append(sentence)
            cancelled.set()

        started = time.monotonic()
        player.speak(sentences(), on_sentence,
                     should_stop=cancelled.is_set, voice="stub")
        elapsed = time.monotonic() - started
        stalled.set()

        self.assertEqual(self.spoken, ["first"])
        self.assertLess(elapsed, 2)
