from .lang import configured_lang

# Canned lines yurad speaks itself, keyed by personality.language; anything else is English.
MESSAGES = {
    "ja": {
        "error": "ごめんね、エラーで返事できなかった。",
        "tool": "ちょっと調べるね。",
    },
    "en": {
        "error": "Sorry, something went wrong and I couldn't reply.",
        "tool": "Let me check on that.",
    },
}

def message_lang() -> str:
    """Unlike the voice, a canned line always needs *some* language."""
    lang = configured_lang() or "en"
    return lang if lang in MESSAGES else "en"


def msg(key: str, **kw) -> str:
    return MESSAGES[message_lang()][key].format(**kw)
