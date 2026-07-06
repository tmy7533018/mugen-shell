"""Convert an AudioSet HF parquet shard to 16 kHz mono wavs for augmentation."""

import io
import os
import sys

import numpy as np
import pyarrow.parquet as pq
import scipy.io.wavfile
import scipy.signal
import soundfile as sf


def main(parquet_path, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    pf = pq.ParquetFile(parquet_path)
    print("schema:", pf.schema_arrow.names)
    n = 0
    for batch in pf.iter_batches(batch_size=16):
        d = batch.to_pydict()
        audio_col = d.get("audio")
        if audio_col is None:
            raise SystemExit(f"no 'audio' column, have: {list(d)}")
        for row in audio_col:
            name = os.path.basename(row.get("path") or f"clip_{n:05d}.flac")
            out = os.path.join(out_dir, os.path.splitext(name)[0] + ".wav")
            if os.path.exists(out):
                n += 1
                continue
            try:
                data, sr = sf.read(io.BytesIO(row["bytes"]), dtype="float32")
            except Exception as e:
                print(f"[warn] {name}: {e}", file=sys.stderr)
                continue
            if data.ndim > 1:
                data = data.mean(axis=1)
            if sr != 16000:
                g = np.gcd(sr, 16000)
                data = scipy.signal.resample_poly(data, 16000 // g, sr // g)
            scipy.io.wavfile.write(out, 16000,
                                   (np.clip(data, -1, 1) * 32767).astype(np.int16))
            n += 1
    print(f"done: {n} clips -> {out_dir}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "data/audioset_09.parquet",
         sys.argv[2] if len(sys.argv) > 2 else "data/audioset_16k")
