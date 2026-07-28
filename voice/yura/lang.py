"""Which language the user said to use — never guessed from audio or text.

Whisper's own detection is not trustworthy enough to steer anything: asked to
auto-detect a Japanese clip it answered English at 0.64 against Japanese 0.011,
and transcribed accordingly. Guessing from the reply's script fares no better,
because "OK" and "了解" would land on different voices inside one conversation.
So the only input is personality.language — the one control the user actually
chose — and when it says nothing the caller falls back rather than picking.
"""

import time

import requests

from .const import AI_URL

_cache: tuple[float, str] = (0.0, "")


def _personality_lang() -> str:
    """personality.language from mugen-ai; empty means "mirror the user"."""
    global _cache
    now = time.time()
    if now - _cache[0] > 60:
        lang = ""
        try:
            r = requests.get(f"{AI_URL}/config", timeout=3)
            lang = str(r.json().get("personality", {}).get("language") or "")
        except requests.RequestException:
            pass
        _cache = (now, lang.strip().lower())
    return _cache[1]


def configured_lang() -> str | None:
    """The chosen language as a 2-letter code, or None when nothing chose one.

    None is a real answer, not a failure: it means "no signal", and callers
    must fall back to their default instead of inventing a language.
    """
    lang = _personality_lang().strip().lower()
    # "auto" is a recognition mode, not a language. Truncating it to "au" is
    # what used to hand Japanese speakers an English voice.
    if lang in ("", "auto"):
        return None
    return lang[:2]
