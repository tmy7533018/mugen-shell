# hey_yura wake word training

Trains the custom "Hey Yura" openWakeWord model used by `yurad.py`
(`voice/models/hey_yura.onnx`). Positives are Japanese-pronounced, so
synthetic clips come from the local VOICEVOX engine (127 speaker styles)
instead of piper's English TTS.

## Pipeline

```sh
./setup_venv.sh                       # torch ROCm + training deps + venv patches
# download data (see below), then:
../.venv/bin/python gen_voicevox.py   # 9,600 clips via VOICEVOX (resumable)
.venv/bin/python convert_audioset.py data/audioset_09.parquet data/audioset_16k
HIP_VISIBLE_DEVICES= CUDA_VISIBLE_DEVICES= \
  .venv/bin/python -m openwakeword.train --training_config hey_yura.yml --augment_clips
.venv/bin/python -m openwakeword.train --training_config hey_yura.yml --train_model
.venv/bin/python verify_model.py      # held-out recall / adversarial FP table
# torch 2.10 exports weights as external data; repack into one file:
.venv/bin/python -c "import onnx; m = onnx.load('out/hey_yura.onnx'); \
  onnx.save_model(m, '../models/hey_yura.onnx', save_as_external_data=False)"
```

`--generate_clips` is never used; gen_voicevox.py fills the same directories.
Augmentation must run with the GPU hidden (onnxruntime here is CPU-only, and
train.py picks the CUDA provider whenever torch sees a GPU). Training itself
uses the GPU.

## data/ (gitignored, ~20 GB)

- `openwakeword_features_ACAV100M_2000_hrs_16bit.npy` + `validation_set_features.npy`
  from `huggingface.co/datasets/davidscripka/openwakeword_features`
- `mit_rirs/` — 270 wavs from `davidscripka/MIT_environmental_impulse_responses` (16khz/)
- AudioSet parquet shards from `agkphysics/AudioSet` (data/bal_train/*.parquet),
  converted with convert_audioset.py

## Results (2026-07-06, held-out VOICEVOX test clips)

recall@0.7 = 0.91, adversarial FP@0.7 = 2.8%, uniform across text variants
and speed 0.85–1.3x. Runtime threshold set to 0.7 in yura-voice.service.
