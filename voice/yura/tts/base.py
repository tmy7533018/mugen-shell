"""What every speech engine has to provide, and how a setting names one.

A voice is stored as `"<engine>:<voice>"`. The engine prefix is the whole
routing decision — there is no separate engine setting to drift from it.
"""

from typing import Protocol


class Engine(Protocol):
    def synth(self, sentence: str, speed: float) -> bytes:
        """Return a WAV of `sentence`, or raise."""


def split_voice(value: str) -> tuple[str, str]:
    """`"aivis:1599412416"` -> `("aivis", "1599412416")`, tolerating junk."""
    engine, _, voice = str(value or "").partition(":")
    return engine.strip(), voice.strip()
