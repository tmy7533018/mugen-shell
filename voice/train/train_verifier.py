"""Train the speaker verifier from recorded positives + other-voice negatives.

Positives: voice/train (record_verifier.py output).
Negatives: wake-debug dumps of false wakes (phone/other voices) — copy the
ones that are NOT the owner into verifier/negative/ first.
Outputs a pickle that yurad loads via YURA_VERIFIER.
"""

import glob
import os
import sys

from openwakeword.custom_verifier_model import train_custom_verifier

BASE = os.path.expanduser("~/.local/share/mugen-shell/verifier")
POS = os.path.join(BASE, "positive")
NEG = os.path.join(BASE, "negative")
OUT = os.path.join(BASE, "hey_yura_verifier.pkl")
# The reference model whose embeddings the verifier sits on top of.
MODEL = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "..", "models", "hey_yura.onnx"))


def main():
    npos = len(glob.glob(os.path.join(POS, "*.wav")))
    nneg = len(glob.glob(os.path.join(NEG, "*.wav")))
    print(f"positives={npos} negatives={nneg}")
    if npos < 5 or nneg < 5:
        sys.exit("need >=5 clips each; record more / copy more negatives")
    train_custom_verifier(
        positive_reference_clips=POS,
        negative_reference_clips=NEG,
        output_path=OUT,
        model_name=MODEL,
    )
    print(f"wrote {OUT}\nSet in yura-voice.service:\n"
          f"  Environment=YURA_VERIFIER={OUT}")


if __name__ == "__main__":
    main()
