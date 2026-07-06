"""Generate "hey yura" wake word training clips with VOICEVOX.

Replaces openWakeWord's piper-sample-generator step: the user says the wake
word with Japanese pronunciation, so VOICEVOX speakers (127 styles) are a
better match than English LibriTTS voices. Writes 16 kHz mono wavs into the
directory layout train.py expects, so --augment_clips / --train_model work
as-is. Resumable: existing files are skipped, params are per-index seeded.
"""

import argparse
import os
import random
import sys
from concurrent.futures import ThreadPoolExecutor

import requests

HOST = "http://127.0.0.1:50021"

POSITIVE = [
    ("ヘイユラ", 0.45),
    ("ヘイ、ユラ", 0.30),
    ("ヘイユーラ", 0.15),
    ("ヘーイユラ", 0.10),
]

# Phonetic near-misses so the model learns a tight decision boundary.
NEAR = [
    "ヘイ", "ユラ", "ユラユラ", "ユラグ", "ユラメク", "ユーラシア", "ユリ",
    "ヘイユキ", "ヘイユカ", "ヘイユナ", "ヘイミク", "ヘイシリ", "ヘイユーロ",
    "ヘイジュード", "ヘイヘイヘイ", "ヘイカモン", "ヘイタクシー",
]

# Everyday Japanese so desk chatter near the mic stays quiet.
COMMON = [
    "おはよう", "こんにちは", "こんばんは", "ありがとう", "そうだね",
    "なるほどね", "オッケー", "うん、わかった", "ちょっと待ってね",
    "今日はいい天気だね", "明日の朝は早く起きないといけない",
    "このコードのバグがなかなか取れない", "夕飯何にしようかな",
    "それでさ、昨日の話なんだけど", "エラーが出てるから直さないと",
    "そろそろ寝ようかな", "天気予報によると明日は雨らしい",
    "お腹減ったなあ", "音楽止めて", "画面明るくして",
]


def get_style_ids():
    speakers = requests.get(f"{HOST}/speakers", timeout=10).json()
    return [st["id"] for sp in speakers for st in sp["styles"]]


def pick_positive(rng):
    r = rng.random()
    acc = 0.0
    for text, w in POSITIVE:
        acc += w
        if r < acc:
            return text
    return POSITIVE[0][0]


def pick_negative(rng):
    return rng.choice(NEAR) if rng.random() < 0.6 else rng.choice(COMMON)


def synth_one(split, out_dir, styles, i):
    path = os.path.join(out_dir, f"{split}_{i:05d}.wav")
    if os.path.exists(path):
        return "skip"
    rng = random.Random(f"{split}:{i}")
    style = rng.choice(styles)
    text = pick_positive(rng) if split.startswith("positive") else pick_negative(rng)
    try:
        q = requests.post(f"{HOST}/audio_query",
                          params={"text": text, "speaker": style}, timeout=30).json()
        q["speedScale"] = rng.uniform(0.85, 1.30)
        q["pitchScale"] = rng.uniform(-0.07, 0.07)
        q["intonationScale"] = rng.uniform(0.6, 1.5)
        q["volumeScale"] = rng.uniform(0.75, 1.0)
        q["prePhonemeLength"] = rng.uniform(0.05, 0.25)
        q["postPhonemeLength"] = rng.uniform(0.05, 0.25)
        q["outputSamplingRate"] = 16000
        q["outputStereo"] = False
        wav = requests.post(f"{HOST}/synthesis",
                            params={"speaker": style}, json=q, timeout=60)
        wav.raise_for_status()
        tmp = path + ".tmp"
        with open(tmp, "wb") as f:
            f.write(wav.content)
        os.replace(tmp, path)
        return "ok"
    except Exception as e:
        print(f"[warn] {split} {i} style={style}: {e}", file=sys.stderr)
        return "err"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="out/hey_yura")
    ap.add_argument("--n-train", type=int, default=4000)
    ap.add_argument("--n-test", type=int, default=800)
    ap.add_argument("--workers", type=int, default=4)
    args = ap.parse_args()

    styles = get_style_ids()
    print(f"{len(styles)} VOICEVOX styles")

    plan = [
        ("positive_train", args.n_train),
        ("positive_test", args.n_test),
        ("negative_train", args.n_train),
        ("negative_test", args.n_test),
    ]
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        for split, n in plan:
            out_dir = os.path.join(args.out, split)
            os.makedirs(out_dir, exist_ok=True)
            results = list(ex.map(
                lambda i: synth_one(split, out_dir, styles, i), range(n)))
            print(f"{split}: ok={results.count('ok')} "
                  f"skip={results.count('skip')} err={results.count('err')}",
                  flush=True)
    print("GEN_DONE")


if __name__ == "__main__":
    main()
