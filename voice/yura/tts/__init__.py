"""Speech output: sentence splitting, engine routing, synthesis, playback.

Consumers import from here rather than the submodules, so the engine layer can
be restructured without touching them.
"""

from .player import (
    clean_for_speech,
    join_spoken,
    play_wav,
    speak,
    speak_guarded,
    split_sentences,
)
from .router import configured_voice, synthesize

# Names re-exported on purpose; without this they read as unused imports.
__all__ = [
    "clean_for_speech",
    "configured_voice",
    "join_spoken",
    "play_wav",
    "speak",
    "speak_guarded",
    "split_sentences",
    "synthesize",
]
