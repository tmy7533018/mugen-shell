import time

import requests

from .const import AI_URL, STT_LANG
from .settings import voice_settings

# Canned lines yurad speaks itself. Keyed by personality.language, hinted by
# voice.sttLang, anything else falls back to English.
MESSAGES = {
    "ja": {
        "error": "ごめんね、エラーで返事できなかった。",
        "enroll_start": "声の登録を始めるよ。ピコンって鳴ったら、ヘイユラ、って言ってね。全部で{n}回だよ。",
        "enroll_more": "いいね、あと{n}回。",
        "enroll_retry": "うまく録れなかった。もう一回お願い。",
        "enroll_done": "登録完了。これからは君の声だけ聞くね。",
        "enroll_fail": "ごめん、登録に失敗しちゃった。",
    },
    "en": {
        "error": "Sorry, something went wrong and I couldn't reply.",
        "enroll_start": "Let's register your voice. After each beep, say: Hey Yura. {n} times in total.",
        "enroll_more": "Nice, {n} to go.",
        "enroll_retry": "That one didn't come through. One more time, please.",
        "enroll_done": "All set. From now on I'll only answer to your voice.",
        "enroll_fail": "Sorry, the enrollment failed.",
    },
}

_lang_cache: tuple[float, str] = (0.0, "")


def speech_lang() -> str:
    global _lang_cache
    now = time.time()
    if now - _lang_cache[0] > 60:
        lang = ""
        try:
            r = requests.get(f"{AI_URL}/config", timeout=3)
            lang = str(r.json().get("personality", {}).get("language") or "")
        except requests.RequestException:
            pass
        _lang_cache = (now, lang.strip().lower()[:2])
    lang = _lang_cache[1] or str(voice_settings().get("sttLang", STT_LANG)).lower()[:2]
    return lang if lang in MESSAGES else "en"


def msg(key: str, **kw) -> str:
    return MESSAGES[speech_lang()][key].format(**kw)
