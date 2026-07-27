"""Language resolution and the voice it selects.

The rule under test: only what the user configured decides, and when nothing
configured a language the code falls back instead of guessing.

Run from voice/:  python -m unittest discover -s tests
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from yura import lang, messages, settings  # noqa: E402
from yura.tts import base, router  # noqa: E402


class _LangFixture(unittest.TestCase):
    def setUp(self):
        self._saved = (settings._settings_cache, settings.SETTINGS_FILE,
                       lang._cache)
        settings.SETTINGS_FILE = "/nonexistent/mugen-shell/settings.json"

    def tearDown(self):
        settings._settings_cache, settings.SETTINGS_FILE, lang._cache = self._saved

    def configure(self, personality: str, voice: dict) -> None:
        # A fresh timestamp stops _personality_lang from calling the backend.
        import time
        lang._cache = (time.time(), personality)
        settings._settings_cache = (0.0, {"voice": voice})


class ConfiguredLang(_LangFixture):
    def test_personality_wins(self):
        self.configure("en", {"sttLang": "ja"})
        self.assertEqual(lang.configured_lang(), "en")

    def test_falls_back_to_stt_language(self):
        self.configure("", {"sttLang": "ja"})
        self.assertEqual(lang.configured_lang(), "ja")

    def test_auto_stt_is_not_a_language(self):
        # "auto" truncated to "au" is what used to hand a Japanese speaker an
        # English voice.
        self.configure("", {"sttLang": "auto"})
        self.assertIsNone(lang.configured_lang())

    def test_nothing_configured_is_none(self):
        self.configure("", {})
        # sttLang is absent, so the module default ("ja") applies.
        self.assertEqual(lang.configured_lang(), "ja")

    def test_locale_is_truncated_to_two_letters(self):
        self.configure("ja-JP", {})
        self.assertEqual(lang.configured_lang(), "ja")


class MessageLang(_LangFixture):
    def test_uses_the_configured_language(self):
        self.configure("ja", {})
        self.assertEqual(messages.message_lang(), "ja")

    def test_unsupported_language_reads_english(self):
        self.configure("fr", {})
        self.assertEqual(messages.message_lang(), "en")

    def test_auto_still_yields_a_language(self):
        # Unlike a voice, a canned line cannot decline to have a language.
        self.configure("", {"sttLang": "auto"})
        self.assertEqual(messages.message_lang(), "en")


class ConfiguredVoice(_LangFixture):
    JA = "aivis:1599412416"
    EN = "local:vits-piper-en_US-lessac-high"

    def test_language_override_wins(self):
        self.configure("", {"sttLang": "ja", "tts": self.EN,
                            "ttsByLang": {"ja": self.JA}})
        self.assertEqual(router.configured_voice(), self.JA)

    def test_other_languages_take_the_default(self):
        self.configure("en", {"sttLang": "ja", "tts": self.EN,
                              "ttsByLang": {"ja": self.JA}})
        self.assertEqual(router.configured_voice(), self.EN)

    def test_no_language_signal_takes_the_default(self):
        # The whole point of returning None from configured_lang: with nothing
        # chosen we must not reach into the map and pick for the user.
        self.configure("", {"sttLang": "auto", "tts": self.EN,
                            "ttsByLang": {"ja": self.JA}})
        self.assertEqual(router.configured_voice(), self.EN)

    def test_missing_map_entry_takes_the_default(self):
        self.configure("fr", {"tts": self.EN, "ttsByLang": {"ja": self.JA}})
        self.assertEqual(router.configured_voice(), self.EN)

    def test_junk_map_is_ignored(self):
        self.configure("", {"sttLang": "ja", "tts": self.EN,
                            "ttsByLang": "not a map"})
        self.assertEqual(router.configured_voice(), self.EN)

    def test_empty_override_does_not_silence_the_turn(self):
        self.configure("", {"sttLang": "ja", "tts": self.EN,
                            "ttsByLang": {"ja": ""}})
        self.assertEqual(router.configured_voice(), self.EN)


class SplitVoice(unittest.TestCase):
    def test_splits_engine_from_voice(self):
        self.assertEqual(base.split_voice("aivis:1599412416"),
                         ("aivis", "1599412416"))

    def test_engine_only(self):
        self.assertEqual(base.split_voice("aivis:"), ("aivis", ""))

    def test_no_separator(self):
        self.assertEqual(base.split_voice("aivis"), ("aivis", ""))

    def test_junk(self):
        self.assertEqual(base.split_voice(""), ("", ""))
        self.assertEqual(base.split_voice(None), ("", ""))


class FindModel(unittest.TestCase):
    def test_refuses_path_traversal(self):
        from yura.tts import local
        self.assertIsNone(local.find_model("../../etc"))
        self.assertIsNone(local.find_model(".ssh"))
        self.assertIsNone(local.find_model(""))

    def test_only_directories_holding_a_model_count(self):
        import tempfile

        from yura.tts import local
        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, "__pycache__"))
            os.makedirs(os.path.join(root, "real-voice"))
            open(os.path.join(root, "real-voice", "model.onnx"), "w").close()
            saved = local.MODEL_PATH
            local.MODEL_PATH = root
            try:
                self.assertEqual(local.available(), ["real-voice"])
                self.assertIsNone(local.find_model("__pycache__"))
            finally:
                local.MODEL_PATH = saved


if __name__ == "__main__":
    unittest.main()
