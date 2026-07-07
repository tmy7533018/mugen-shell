"""Record the owner's wake-word clips for the speaker verifier.

Captures short "Hey Yura" utterances from the same mic yurad listens on
(the echo-cancelled default source), so the verifier learns the voice as
it actually arrives. Negatives come from the wake-debug dumps of other
voices; see train_verifier.py.
"""

import os
import sys
import time
import wave

import numpy as np
import sounddevice as sd

SR = 16000
OUT = os.path.expanduser("~/.local/share/mugen-shell/verifier/positive")
N = int(sys.argv[1]) if len(sys.argv) > 1 else 20
DUR = 2.0


def main():
    os.makedirs(OUT, exist_ok=True)
    start = len(os.listdir(OUT))
    print(f"Recording {N} clips of \"Hey Yura\" ({DUR:.0f}s each) into {OUT}")
    print("Say it a little differently each time — normal, fast, quiet, "
          "farther away. Ctrl-C to stop early.\n")
    for i in range(N):
        input(f"[{i + 1}/{N}] Enter, then say \"Hey Yura\"...")
        rec = sd.rec(int(DUR * SR), samplerate=SR, channels=1, dtype="int16")
        sd.wait()
        path = os.path.join(OUT, f"heyyura_{start + i:03d}.wav")
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(rec.tobytes())
        peak = np.abs(rec).max() / 32768.0
        warn = "  (quiet — closer/louder?)" if peak < 0.05 else ""
        print(f"    saved {os.path.basename(path)} peak={peak:.2f}{warn}")
    print(f"\nDone. {len(os.listdir(OUT))} positive clips total.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nstopped.")
