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
    def test_personality_is_the_only_source(self):
        self.configure("en", {})
        self.assertEqual(lang.configured_lang(), "en")

    def test_auto_is_not_a_language(self):
        # "auto" truncated to "au" is what used to hand a Japanese speaker an
        # English voice.
        self.configure("auto", {})
        self.assertIsNone(lang.configured_lang())

    def test_nothing_configured_is_none(self):
        self.configure("", {})
        self.assertIsNone(lang.configured_lang())

    def test_locale_is_truncated_to_two_letters(self):
        self.configure("ja-JP", {})
        self.assertEqual(lang.configured_lang(), "ja")


class PersonalityFetch(unittest.TestCase):
    """The real /config parse, which the _LangFixture stub bypasses."""

    def setUp(self):
        self._saved = lang._cache
        lang._cache = (0.0, "")

    def tearDown(self):
        lang._cache = self._saved

    def _fetch(self, payload):
        class _Resp:
            def json(self_inner):
                return payload
        saved = lang.ai.get
        lang.ai.get = lambda *a, **kw: _Resp()
        try:
            lang._cache = (0.0, "")
            return lang._personality_lang()
        finally:
            lang.ai.get = saved

    def test_reads_the_nested_config(self):
        self.assertEqual(
            self._fetch({"path": "/x", "config": {"personality": {"language": "ja"}}}),
            "ja")

    def test_tolerates_an_unwrapped_body(self):
        self.assertEqual(
            self._fetch({"personality": {"language": "en"}}), "en")

    def test_missing_personality_is_empty(self):
        self.assertEqual(self._fetch({"config": {}}), "")


class MessageLang(_LangFixture):
    def test_uses_the_configured_language(self):
        self.configure("ja", {})
        self.assertEqual(messages.message_lang(), "ja")

    def test_unsupported_language_reads_english(self):
        self.configure("fr", {})
        self.assertEqual(messages.message_lang(), "en")

    def test_auto_still_yields_a_language(self):
        # Unlike a voice, a canned line cannot decline to have a language.
        self.configure("", {})
        self.assertEqual(messages.message_lang(), "en")


class ConfiguredVoice(_LangFixture):
    JA = "aivis:1599412416"
    EN = "local:vits-piper-en_US-lessac-high"

    def test_language_override_wins(self):
        self.configure("ja", {"tts": self.EN, "ttsByLang": {"ja": self.JA}})
        self.assertEqual(router.configured_voice(), self.JA)

    def test_other_languages_take_the_default(self):
        self.configure("en", {"tts": self.EN, "ttsByLang": {"ja": self.JA}})
        self.assertEqual(router.configured_voice(), self.EN)

    def test_no_language_signal_takes_the_default(self):
        # The whole point of returning None from configured_lang: with nothing
        # chosen we must not reach into the map and pick for the user.
        self.configure("", {"tts": self.EN, "ttsByLang": {"ja": self.JA}})
        self.assertEqual(router.configured_voice(), self.EN)

    def test_missing_map_entry_takes_the_default(self):
        self.configure("fr", {"tts": self.EN, "ttsByLang": {"ja": self.JA}})
        self.assertEqual(router.configured_voice(), self.EN)

    def test_junk_map_is_ignored(self):
        self.configure("ja", {"tts": self.EN, "ttsByLang": "not a map"})
        self.assertEqual(router.configured_voice(), self.EN)

    def test_empty_override_does_not_silence_the_turn(self):
        self.configure("ja", {"tts": self.EN, "ttsByLang": {"ja": ""}})
        self.assertEqual(router.configured_voice(), self.EN)


class BuildEngine(unittest.TestCase):
    """A bad voice string must cost the user a voice, never the whole reply."""

    def setUp(self):
        import tempfile

        from yura.tts import local
        self._tmp = tempfile.TemporaryDirectory()
        os.makedirs(os.path.join(self._tmp.name, "installed-voice"))
        open(os.path.join(self._tmp.name, "installed-voice", "m.onnx"), "w").close()
        self._saved = local.MODEL_PATH
        local.MODEL_PATH = self._tmp.name

    def tearDown(self):
        from yura.tts import local
        local.MODEL_PATH = self._saved
        self._tmp.cleanup()

    def test_missing_model_falls_back_to_an_installed_one(self):
        e = router._build("local:typo-in-settings")
        self.assertEqual(os.path.basename(e.path), "installed-voice")

    def test_unknown_engine_falls_back_too(self):
        e = router._build("nosuchengine:whatever")
        self.assertEqual(os.path.basename(e.path), "installed-voice")

    def test_empty_value_falls_back(self):
        e = router._build("")
        self.assertEqual(os.path.basename(e.path), "installed-voice")

    def test_named_model_is_used_when_present(self):
        e = router._build("local:installed-voice")
        self.assertEqual(os.path.basename(e.path), "installed-voice")

    def test_http_engines_do_not_need_a_local_model(self):
        e = router._build("aivis:123")
        self.assertEqual(e.speaker, 123)


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


class EnginePrewarm(_LangFixture):
    def setUp(self):
        super().setUp()
        from yura.tts import service
        self.service = service
        self._svc = (service.SERVICE, service.prewarm)
        service.SERVICE = "aivisspeech-engine.service"
        self.warmed = 0
        service.prewarm = self._count

    def tearDown(self):
        self.service.SERVICE, self.service.prewarm = self._svc
        super().tearDown()

    def _count(self):
        self.warmed += 1

    def test_a_japanese_turn_warms_the_engine(self):
        self.configure("ja", {"ttsByLang": {"ja": "aivis:1878365376"}})
        router.prewarm()
        self.assertEqual(self.warmed, 1)

    def test_a_local_voice_does_not(self):
        self.configure("en", {"tts": "local:vits-piper-en_US-lessac-high"})
        router.prewarm()
        self.assertEqual(self.warmed, 0)

    def test_the_read_aloud_voice_overrides_the_setting(self):
        self.configure("en", {"tts": "local:vits-piper-en_US-lessac-high"})
        router.prewarm("aivis:1878365376")
        self.assertEqual(self.warmed, 1)

    def test_nothing_is_managed_without_the_service_env(self):
        self.service.SERVICE = ""
        self.configure("ja", {"ttsByLang": {"ja": "aivis:1878365376"}})
        router.prewarm()
        self.assertEqual(self.warmed, 0)


class UnmanagedEngine(unittest.TestCase):
    def test_construction_does_not_poll_an_engine_we_do_not_start(self):
        import time

        from yura.tts import service, voicevox_api
        saved = (service.SERVICE, voicevox_api.BASE_URLS["voicevox"])
        service.SERVICE = "aivisspeech-engine.service"
        voicevox_api.BASE_URLS["voicevox"] = "http://127.0.0.1:1"
        try:
            started = time.perf_counter()
            engine = voicevox_api.VoicevoxEngine("voicevox", "")
            elapsed = time.perf_counter() - started
        finally:
            service.SERVICE, voicevox_api.BASE_URLS["voicevox"] = saved
        self.assertFalse(engine.managed)
        self.assertLess(elapsed, 2.0)


if __name__ == "__main__":
    unittest.main()
