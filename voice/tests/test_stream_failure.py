"""A reply that dies mid-stream must reach the caller, not end the turn in silence.

Run from voice/:  python -m unittest discover -s tests
"""

import os
import sys
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
