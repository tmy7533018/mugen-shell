"""Values more than one module needs; everything else lives with its consumer."""

import os

# mugen-ai listens on a unix socket; the host in AI_URL is inert but requests still needs one.
AI_SOCKET = os.environ.get("MUGEN_AI_SOCKET") or os.path.join(
    os.environ.get("XDG_RUNTIME_DIR", "/run/user/%d" % os.getuid()),
    "mugen-ai", "mugen-ai.sock")
AI_URL = "http://localhost"
STT_LANG = os.environ.get("YURA_VOICE_LANG", "ja")

_CONFIG_HOME = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
_DATA_HOME = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")

CONFIG_DIR = os.path.join(_CONFIG_HOME, "mugen-shell")
DATA_DIR = os.path.join(_DATA_HOME, "mugen-shell")
QS_CONFIG_DIR = os.path.join(_CONFIG_HOME, "quickshell", "mugen-shell")

SR = 16000
CHUNK = 1280                      # 80 ms
