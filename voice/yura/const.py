"""Values more than one module needs; everything else lives with its consumer."""

import os

AI_URL = f"http://127.0.0.1:{os.environ.get('MUGEN_AI_PORT', '11435')}"
STT_LANG = os.environ.get("YURA_VOICE_LANG", "ja")

_CONFIG_HOME = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
_DATA_HOME = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")

CONFIG_DIR = os.path.join(_CONFIG_HOME, "mugen-shell")
DATA_DIR = os.path.join(_DATA_HOME, "mugen-shell")
QS_CONFIG_DIR = os.path.join(_CONFIG_HOME, "quickshell", "mugen-shell")

SR = 16000
CHUNK = 1280                      # 80 ms, what openWakeWord expects
