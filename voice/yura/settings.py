import json
import os

# Live knobs (voice.enabled, voice.wakeOpens) come from the shell's
# settings.json so the Settings GUI controls the daemon without a restart.
SETTINGS_FILE = os.path.expanduser("~/.config/mugen-shell/settings.json")

_settings_cache: tuple[float, dict] = (0.0, {})


def settings() -> dict:
    global _settings_cache
    try:
        mtime = os.path.getmtime(SETTINGS_FILE)
        if mtime != _settings_cache[0]:
            with open(SETTINGS_FILE) as f:
                _settings_cache = (mtime, json.load(f))
    except Exception:
        pass  # keep last good values; defaults apply on first failure
    return _settings_cache[1]


def voice_settings() -> dict:
    return settings().get("voice", {})


def voice_float(key: str, fallback: float, lo: float, hi: float) -> float:
    """Clamped float from voice settings; junk from a hand-edit falls back.

    These are read per frame on the audio path, where a raise would take the
    daemon down into a restart cycle.
    """
    try:
        value = float(voice_settings().get(key, fallback))
    except (TypeError, ValueError):
        value = fallback
    return min(max(value, lo), hi)
