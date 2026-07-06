#!/usr/bin/env bash
# Training venv setup for the hey_yura wake word model.
# torch ROCm first (biggest download), then openwakeword training deps.
set -x
cd "$(dirname "$0")"
PIP=.venv/bin/pip

$PIP install torch torchaudio --index-url https://download.pytorch.org/whl/rocm7.0 || exit 1
# tflite-runtime has no cp314 wheel; ONNX path only (same trick as runtime venv)
$PIP install openwakeword==0.6.0 --no-deps || exit 1
$PIP install onnxruntime tqdm scipy scikit-learn requests pyyaml \
    mutagen torchinfo torchmetrics audiomentations torch-audiomentations \
    pronouncing acoustics datasets soundfile || exit 1
$PIP install speechbrain || echo "SPEECHBRAIN_FAILED (will shim)"
$PIP install onnxscript onnx || exit 1

.venv/bin/python apply_patches.py || exit 1

.venv/bin/python - <<'EOF'
import torch
print("torch", torch.__version__, "cuda/hip:", torch.cuda.is_available())
try:
    import openwakeword.data
    print("openwakeword.data import OK")
except Exception as e:
    print("openwakeword.data import FAILED:", e)
EOF
echo SETUP_DONE
