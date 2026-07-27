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
