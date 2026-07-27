"""Speech output: sentence splitting, synthesis dispatch, playback.

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

# Names re-exported on purpose; without this they read as unused imports.
__all__ = [
    "clean_for_speech",
    "join_spoken",
    "play_wav",
    "speak",
    "speak_guarded",
    "split_sentences",
]
