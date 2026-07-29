import http.server
import json
import os
import socket
import socketserver
import threading

from .log import log
from .tts import prewarm_tts, speak_guarded

# The shell drives the daemon over this socket: read-aloud, starting and
# cancelling a turn, and voice enrollment. A socket rather than signals or a
# second process — signals carry no arguments and give no answer, and on the
# Nix path yurad.py lives in the store behind a wrapped interpreter, so it
# can't be re-invoked as a one-shot.
CTL_SOCKET = os.path.join(
    os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}",
    "mugen-shell", "yura-ctl.sock")
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

    def speak(self, text: str, voice: str | None = None) -> None:
        gen = self._bump()
        # Nothing precedes the synthesis here, so a stopped engine is heard as
        # a lag before the first word rather than hidden behind a turn.
        prewarm_tts(voice)
        threading.Thread(target=self._run, args=(text, gen, voice),
                         daemon=True).start()

    def _run(self, text: str, gen: int, voice: str | None) -> None:
        # The lock keeps a preempted utterance from overlapping its successor:
        # the in-flight one cuts out on the generation bump, and whoever wakes
        # up holding a stale generation gives up its turn.
        with self._play:
            if gen != self._gen:
                return
            try:
                speak_guarded(text, should_stop=lambda: gen != self._gen,
                              voice=voice)
            except Exception as e:
                log("speak", str(e))


class _CtlServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    address_family = socket.AF_UNIX
    daemon_threads = True

    def server_bind(self) -> None:
        # HTTPServer's own bind unpacks server_address as (host, port), which
        # a filesystem path isn't.
        socketserver.TCPServer.server_bind(self)
        self.server_name = "localhost"
        self.server_port = 0


class _CtlHandler(http.server.BaseHTTPRequestHandler):
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

    def _body(self) -> dict | None:
        """Read the request body, or None once an error has been answered.

        Draining happens on every path, before any early return: what's left
        unread gets parsed as the next request on this kept-alive connection.
        """
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            self.close_connection = True
            self._reply(400, {"error": "bad content-length"})
            return None
        raw = self.rfile.read(length)
        try:
            return json.loads(raw or b"{}")
        except (TypeError, ValueError) as e:
            self._reply(400, {"error": str(e)})
            return None

    def do_GET(self) -> None:
        if self._body() is None:
            return
        if self.path == "/state":
            self._reply(200, self.server.yurad.state())
        elif self.path == "/voices":
            from .tts.router import catalog
            self._reply(200, {"voices": catalog()})
        else:
            self._reply(404, {"error": "unknown endpoint"})

    def do_POST(self) -> None:
        body = self._body()
        if body is None:
            return
        daemon = self.server.yurad
        if self.path == "/speak":
            text = str(body.get("text") or "").strip()[:SPEAK_MAX_CHARS]
            if not text:
                self._reply(400, {"error": "empty text"})
                return
            # Absent means "whatever the language routing picks"; the Settings
            # picker passes one to audition a voice before saving it.
            daemon.read_aloud.speak(text, str(body.get("voice") or "") or None)
        elif self.path == "/stop":
            daemon.read_aloud.stop()
        elif self.path == "/turn":
            daemon.request_turn(bool(body.get("fresh")))
        elif self.path == "/ptt/start":
            daemon.request_ptt(True)
        elif self.path == "/ptt/stop":
            daemon.request_ptt(False)
        elif self.path == "/cancel":
            daemon.request_cancel()
        elif self.path == "/enroll":
            daemon.request_enroll()
        else:
            self._reply(404, {"error": "unknown endpoint"})
            return
        self._reply(200, {"ok": True})


def serve_control_socket(daemon) -> None:
    try:
        os.makedirs(os.path.dirname(CTL_SOCKET), exist_ok=True)
        # SIGTERM leaves through os._exit, so the last run's socket is still
        # on disk and bind would fail on it.
        if os.path.exists(CTL_SOCKET):
            os.remove(CTL_SOCKET)
        server = _CtlServer(CTL_SOCKET, _CtlHandler)
        os.chmod(CTL_SOCKET, 0o600)
    except OSError as e:
        log("ctl", f"socket unavailable: {e}")
        return
    server.yurad = daemon
    threading.Thread(target=server.serve_forever, daemon=True).start()
    log("ctl", f"listening on {CTL_SOCKET}")
