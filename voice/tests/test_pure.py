"""Pure-function tests for the speech text pipeline and settings clamping.

Run from voice/:  python -m unittest discover -s tests
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from yura import settings  # noqa: E402
from yura.tts.player import (  # noqa: E402
    clean_for_speech,
    join_spoken,
    split_sentences,
)


class CleanForSpeech(unittest.TestCase):
    def test_strips_markdown(self):
        self.assertEqual(
            clean_for_speech("**太字** と `code` と [link](http://x) だよ"),
            "太字 と code と link だよ")

    def test_link_keeps_label_drops_url(self):
        self.assertEqual(clean_for_speech("[ここ](https://example.com)"), "ここ")

    def test_fenced_block_goes_entirely(self):
        self.assertEqual(clean_for_speech("前\n```\nprint(1)\n```\n後"), "前\n \n後")

    def test_strips_emoji(self):
        self.assertEqual(clean_for_speech("やったね🎉"), "やったね")

    def test_collapses_runs_of_spaces(self):
        self.assertEqual(clean_for_speech("\t スペース   が   多い \t"),
                         "スペース が 多い")


class SplitSentences(unittest.TestCase):
    def test_japanese_full_stop(self):
        self.assertEqual(
            split_sentences("これは長めの日本語の文だよ。次の文もそれなりに長いから独立するはず。"),
            ["これは長めの日本語の文だよ。", "次の文もそれなりに長いから独立するはず。"])

    def test_ascii_period_needs_whitespace(self):
        self.assertEqual(split_sentences("Hello there friend. How are you doing today?"),
                         ["Hello there friend.", "How are you doing today?"])

    def test_decimal_survives(self):
        # The whitespace requirement after "." is what keeps 3.14 in one piece.
        self.assertEqual(split_sentences("3.14 は円周率。"), ["3.14 は円周率。"])

    def test_short_fragment_glues_to_previous(self):
        # Under 8 chars is a fragment so TTS doesn't gasp; the glue is bare concatenation.
        self.assertEqual(split_sentences("A. B. Longer sentence follows here."),
                         ["A.B.", "Longer sentence follows here."])

    def test_first_sentence_is_never_glued(self):
        self.assertEqual(split_sentences("こんにちは。元気ですか。"),
                         ["こんにちは。元気ですか。"])

    def test_empty(self):
        self.assertEqual(split_sentences(""), [])
        self.assertEqual(split_sentences("   "), [])


class JoinSpoken(unittest.TestCase):
    def test_latin_regains_the_space(self):
        self.assertEqual(join_spoken(["Hello there friend.", "How are you?"]),
                         "Hello there friend. How are you?")

    def test_japanese_runs_flush(self):
        self.assertEqual(join_spoken(["これは長めの文だよ。", "次の文。"]),
                         "これは長めの文だよ。次の文。")

    def test_empty(self):
        self.assertEqual(join_spoken([]), "")


class VoiceFloat(unittest.TestCase):
    def setUp(self):
        self._saved = (settings._settings_cache, settings.SETTINGS_FILE)
        # A path that cannot be stat'd keeps the cache instead of reading real settings.
        settings.SETTINGS_FILE = "/nonexistent/mugen-shell/settings.json"

    def tearDown(self):
        settings._settings_cache, settings.SETTINGS_FILE = self._saved

    def _set(self, voice: dict) -> None:
        settings._settings_cache = (0.0, {"voice": voice})

    def test_reads_the_value(self):
        self._set({"speed": 1.2})
        self.assertAlmostEqual(settings.voice_float("speed", 1.0, 0.5, 2.0), 1.2)

    def test_clamps_high_and_low(self):
        self._set({"speed": 99})
        self.assertAlmostEqual(settings.voice_float("speed", 1.0, 0.5, 2.0), 2.0)
        self._set({"speed": -5})
        self.assertAlmostEqual(settings.voice_float("speed", 1.0, 0.5, 2.0), 0.5)

    def test_missing_key_falls_back(self):
        self._set({})
        self.assertAlmostEqual(settings.voice_float("speed", 1.1, 0.5, 2.0), 1.1)

    def test_junk_from_a_hand_edit_falls_back(self):
        for junk in ("fast", None, [], {}):
            self._set({"speed": junk})
            self.assertAlmostEqual(settings.voice_float("speed", 1.1, 0.5, 2.0), 1.1)

    def test_fallback_is_itself_clamped(self):
        # A caller's default outside the range must not slip through.
        self._set({})
        self.assertAlmostEqual(settings.voice_float("speed", 9.0, 0.5, 2.0), 2.0)


if __name__ == "__main__":
    unittest.main()
