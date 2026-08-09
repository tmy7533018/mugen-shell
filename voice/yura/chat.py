import json
import os
import time

import requests

from .aiclient import session as ai
from .const import AI_URL
from .lang import configured_lang
from .log import log
from .settings import settings
from .shell import yura_ipc

CONV_IDLE_ROTATE_S = float(os.environ.get("YURA_CONV_IDLE_ROTATE", "3600"))


class Chat:
    """Keeps one mugen-ai conversation, rotated after an idle gap."""

    def __init__(self):
        self.conversation_id = 0
        self.model = ""  # what the bound conversation was seeded with
        self.last_turn = 0.0

    def reset(self) -> None:
        self.conversation_id = 0
        self.model = ""

    def maybe_rotate(self, want: str | None = None) -> None:
        """Every start-a-fresh-conversation policy lives here."""
        if not self.conversation_id:
            return
        # A long silence usually means a new topic, and long-term memory bridges the cut.
        if time.time() - self.last_turn > CONV_IDLE_ROTATE_S:
            log("chat", "idle gap, rotating to a new conversation")
            self.reset()
            return
        # The bound model always wins on the backend, so compare against what this conversation was seeded with.
        if want is None:
            want = settings().get("ai", {}).get("barModel", "")
        if want and self.model and want != self.model:
            log("chat", f"model changed to {want}, rotating conversation")
            self.reset()

    def ask(self, text: str) -> str:
        # One read serves both the rotation check and the payload, so a mid-turn write can't split it.
        want = settings().get("ai", {}).get("barModel", "")
        self.maybe_rotate(want)
        try:
            reply = self._ask(text, want)
        except requests.HTTPError as e:
            # 400 with a bound id = the conversation was deleted from the panel behind our back.
            if (self.conversation_id and e.response is not None
                    and e.response.status_code == 400):
                log("chat", "conversation gone, starting a new one")
                self.reset()
                reply = self._ask(text, want)
            else:
                raise
        self.last_turn = time.time()
        return reply

    def _ask(self, text: str, model: str = "") -> str:
        parts: list[str] = []
        payload = {"message": text, "conversation_id": self.conversation_id,
                   "voice": True}
        lang = configured_lang()
        if lang:
            payload["language"] = lang
        # Voice mirrors into the bar pill, so it follows the bar's model knob; empty means the default.
        if model:
            payload["model"] = model
        with ai.post(f"{AI_URL}/chat", json=payload, stream=True,
                           timeout=(5, 300)) as r:
            r.raise_for_status()
            # The SSE content-type carries no charset, so requests would fall back to latin-1.
            r.encoding = "utf-8"
            for line in r.iter_lines(decode_unicode=True):
                if not line or not line.startswith("data: "):
                    continue
                ev = json.loads(line[6:])
                if "conversation_id" in ev and not self.conversation_id:
                    self.conversation_id = ev["conversation_id"]
                    # Seed from the knob we sent; the backend echo only fills in when it was empty.
                    self.model = model or ev.get("model", "")
                    # Selection alone is not broadcast, so an open panel would keep its old conversation.
                    ai.post(
                        f"{AI_URL}/conversations/{self.conversation_id}/select",
                        timeout=3)
                    yura_ipc("show_conversation", str(self.conversation_id))
                if "content" in ev:
                    parts.append(ev["content"])
                if "tool_confirm" in ev:
                    # Voice can't render an approval card; decline and let the model explain.
                    ai.post(f"{AI_URL}/chat/confirm", json={
                        "confirm_id": ev["tool_confirm"]["confirm_id"],
                        "approved": False}, timeout=5)
                if ev.get("error"):
                    raise RuntimeError(ev["error"])
                if ev.get("done"):
                    break
        return "".join(parts)
