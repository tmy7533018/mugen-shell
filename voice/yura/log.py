import threading
import time

log_lock = threading.Lock()


def log(tag: str, msg: str = "") -> None:
    with log_lock:
        print(f"{time.strftime('%H:%M:%S')} [{tag:<10}] {msg}", flush=True)
