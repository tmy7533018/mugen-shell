"""HTTP to mugen-ai over its unix socket.

requests has no unix transport of its own, so the socket is wired in as an
adapter rather than reworking every call site: streaming, raise_for_status and
HTTPError.response all keep behaving the way the callers expect.
"""

import socket

import requests
from requests.adapters import HTTPAdapter
from urllib3.connection import HTTPConnection
from urllib3.connectionpool import HTTPConnectionPool

from .const import AI_SOCKET, AI_URL


class _UnixConnection(HTTPConnection):
    def __init__(self, socket_path, **kwargs):
        super().__init__("localhost", **kwargs)
        self.socket_path = socket_path

    def _new_conn(self):
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        if isinstance(self.timeout, (int, float)):
            sock.settimeout(self.timeout)
        sock.connect(self.socket_path)
        return sock


class _UnixConnectionPool(HTTPConnectionPool):
    def __init__(self, socket_path, **kwargs):
        super().__init__("localhost", **kwargs)
        self.socket_path = socket_path

    def _new_conn(self):
        return _UnixConnection(self.socket_path, timeout=self.timeout)


class UnixAdapter(HTTPAdapter):
    def __init__(self, socket_path, **kwargs):
        self.socket_path = socket_path
        super().__init__(**kwargs)

    def get_connection_with_tls_context(self, request, verify, proxies=None, cert=None):
        return _UnixConnectionPool(self.socket_path)

    # requests before 2.32 asks through this name instead.
    def get_connection(self, url, proxies=None):
        return _UnixConnectionPool(self.socket_path)


def _build():
    s = requests.Session()
    s.mount(AI_URL, UnixAdapter(AI_SOCKET))
    return s


session = _build()
