"""Values more than one module needs; everything else lives with its consumer."""

import os

AI_URL = f"http://127.0.0.1:{os.environ.get('MUGEN_AI_PORT', '11435')}"
STT_LANG = os.environ.get("YURA_VOICE_LANG", "ja")

SR = 16000
CHUNK = 1280                      # 80 ms, what openWakeWord expects
