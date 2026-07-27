import http.server
import json
import os
import socket
import socketserver
import threading

from .log import log
from .tts import speak_guarded

# The chat panel's read-aloud button hands text to the running daemon here.
# A socket rather than a second process: on the Nix path yurad.py lives in the
# store behind a wrapped interpreter, so it can't be re-invoked as a one-shot.
SPEAK_SOCKET = os.path.join(
    os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}",
    "mugen-shell", "yura-speak.sock")
# A pasted wall of text would park the synthesis queue for many minutes.
SPEAK_MAX_CHARS = 4000


class ReadAloud:
    """Speaks text handed over by the UI, one utterance at a time."""

    def __init__(self):
        self._play = threading.Lock()
        self._gen_lock = threading.Lock()
        self._gen = 0

    def _bump(self) -> int:
        with self._gen_lock:
            self._gen += 1
            return self._gen

    def stop(self) -> None:
        self._bump()

    def speak(self, text: str) -> None:
        gen = self._bump()
        threading.Thread(target=self._run, args=(text, gen), daemon=True).start()

    def _run(self, text: str, gen: int) -> None:
        # The lock keeps a preempted utterance from overlapping its successor:
        # the in-flight one cuts out on the generation bump, and whoever wakes
        # up holding a stale generation gives up its turn.
        with self._play:
            if gen != self._gen:
                return
            try:
                speak_guarded(text, should_stop=lambda: gen != self._gen)
            except Exception as e:
                log("speak", str(e))


class _SpeakServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    address_family = socket.AF_UNIX
    daemon_threads = True

    def server_bind(self) -> None:
        # HTTPServer's own bind unpacks server_address as (host, port), which
        # a filesystem path isn't.
        socketserver.TCPServer.server_bind(self)
        self.server_name = "localhost"
        self.server_port = 0


class _SpeakHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    timeout = 5

    def log_message(self, fmt, *args) -> None:
        pass

    def address_string(self) -> str:
        # The default reads client_address[0]; an AF_UNIX peer has no address.
        return "local"

    def _reply(self, code: int, body: dict) -> None:
        raw = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_POST(self) -> None:
        # Drain the body on every path, before any early return: what's left
        # unread gets parsed as the next request on this kept-alive connection.
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            self.close_connection = True
            self._reply(400, {"error": "bad content-length"})
            return
        raw = self.rfile.read(length)
        if self.path == "/stop":
            self.server.read_aloud.stop()
            self._reply(200, {"ok": True})
            return
        if self.path != "/speak":
            self._reply(404, {"error": "unknown endpoint"})
            return
        try:
            body = json.loads(raw or b"{}")
            text = str(body.get("text") or "").strip()[:SPEAK_MAX_CHARS]
        except (AttributeError, TypeError, ValueError) as e:
            self._reply(400, {"error": str(e)})
            return
        if not text:
            self._reply(400, {"error": "empty text"})
            return
        self.server.read_aloud.speak(text)
        self._reply(200, {"ok": True})


def serve_speak_socket(read_aloud: ReadAloud) -> None:
    try:
        os.makedirs(os.path.dirname(SPEAK_SOCKET), exist_ok=True)
        # SIGTERM leaves through os._exit, so the last run's socket is still
        # on disk and bind would fail on it.
        if os.path.exists(SPEAK_SOCKET):
            os.remove(SPEAK_SOCKET)
        server = _SpeakServer(SPEAK_SOCKET, _SpeakHandler)
        os.chmod(SPEAK_SOCKET, 0o600)
    except OSError as e:
        log("speak", f"socket unavailable: {e}")
        return
    server.read_aloud = read_aloud
    threading.Thread(target=server.serve_forever, daemon=True).start()
    log("speak", f"listening on {SPEAK_SOCKET}")
