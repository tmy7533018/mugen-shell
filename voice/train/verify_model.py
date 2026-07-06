"""Held-out check for the trained wake word model.

Reports recall on positive_test clips and false-positive rate on the
adversarial negative_test clips (raw wavs, no augmentation) at several
thresholds, so we can pick a sane YURA_WAKE_THRESHOLD.
"""

import glob
import sys

import numpy as np
from openwakeword.model import Model

MODEL = sys.argv[1] if len(sys.argv) > 1 else "out/hey_yura.onnx"
THRESHOLDS = [0.3, 0.5, 0.7, 0.9]


def max_score(m, path, name):
    m.reset()
    scores = m.predict_clip(path)
    return max(s[name] for s in scores)


def main():
    m = Model(wakeword_models=[MODEL], inference_framework="onnx")
    name = list(m.models.keys())[0]

    pos = sorted(glob.glob("out/hey_yura/positive_test/*.wav"))
    neg = sorted(glob.glob("out/hey_yura/negative_test/*.wav"))
    print(f"model={MODEL} key={name} pos={len(pos)} neg={len(neg)}")

    pos_scores = np.array([max_score(m, p, name) for p in pos])
    neg_scores = np.array([max_score(m, p, name) for p in neg])

    print(f"pos scores: median={np.median(pos_scores):.3f} p10={np.percentile(pos_scores, 10):.3f}")
    print(f"neg scores: median={np.median(neg_scores):.3f} p99={np.percentile(neg_scores, 99):.3f}")
    for t in THRESHOLDS:
        recall = (pos_scores >= t).mean()
        fp = (neg_scores >= t).mean()
        print(f"threshold {t:.1f}: recall={recall:.3f} adversarial_fp={fp:.3f}")


if __name__ == "__main__":
    main()
