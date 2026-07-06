"""Idempotent patches for the training venv (Python 3.14 + ROCm torch).

Run after setup_venv.sh installs everything. Each patch is a no-op if
already applied. Why each one exists:

- acoustics/directivity.py: scipy >= 1.17 removed sph_harm; only the
  colored-noise generator is used, so a signature-compatible alias suffices.
- openwakeword/data.py + torch_audiomentations/utils/io.py: torchaudio 2.10
  delegates load/info to torchcodec, which ships no ROCm build; all training
  audio is plain 16 kHz wav, so soundfile covers everything.
- openwakeword/train.py: guard the unconditional piper import (clips come
  from gen_voicevox.py), guard tflite conversion (no tensorflow), honor
  augmentation_rounds in n_total (upstream drops the extra rounds), and
  force the fork start method (3.14 defaults to forkserver, which cannot
  pickle the lambda-holding batch generator).
"""

import os
import sys


def patch(path, pairs, marker):
    src = open(path).read()
    if marker in src:
        print(f"skip (already patched): {path}")
        return
    for old, new, count in pairs:
        assert src.count(old) == count, (path, old[:60], src.count(old))
        src = src.replace(old, new)
    open(path, "w").write(src)
    print(f"patched: {path}")


def main():
    import acoustics
    import openwakeword
    import torch_audiomentations

    acou = os.path.dirname(acoustics.__file__)
    oww = os.path.dirname(openwakeword.__file__)
    ta = os.path.dirname(torch_audiomentations.__file__)

    patch(os.path.join(acou, "directivity.py"), [(
        "from scipy.special import sph_harm  # pylint: disable=no-name-in-module\n",
        "try:\n"
        "    from scipy.special import sph_harm  # pylint: disable=no-name-in-module\n"
        "except ImportError:  # scipy >= 1.17 removed sph_harm\n"
        "    from scipy.special import sph_harm_y\n\n"
        "    def sph_harm(m, n, theta, phi):\n"
        "        return sph_harm_y(n, m, phi, theta)\n",
        1)], marker="sph_harm_y")

    sf_shim = '''import torchaudio
import soundfile as _soundfile


def _sf_load(path):
    data, sr = _soundfile.read(path, dtype="float32", always_2d=True)
    return torch.from_numpy(data.T.copy()), sr


class _SFInfo:
    def __init__(self, path):
        info = _soundfile.info(path)
        self.num_frames = info.frames
        self.sample_rate = info.samplerate
        self.num_channels = info.channels
        digits = "".join(c for c in (info.subtype or "") if c.isdigit())
        self.bits_per_sample = int(digits) if digits else 16


def _sf_info(path):
    return _SFInfo(path)
'''
    patch(os.path.join(oww, "data.py"), [
        ("import torchaudio\n", sf_shim, 1),
        ("torchaudio.load(", "_sf_load(", 5),
        ("torchaudio.info(", "_sf_info(", 3),
    ], marker="_sf_load")

    io_shim = '''import torchaudio
import torch as _torch
import soundfile as _soundfile


class _SFInfo:
    def __init__(self, path):
        _i = _soundfile.info(path)
        self.num_frames = _i.frames
        self.sample_rate = _i.samplerate
        self.num_channels = _i.channels


def _sf_info(path):
    return _SFInfo(path)


def _sf_load(path, frame_offset=0, num_frames=-1):
    data, sr = _soundfile.read(str(path), dtype="float32", always_2d=True,
                               start=frame_offset, frames=num_frames)
    return _torch.from_numpy(data.T.copy()), sr
'''
    patch(os.path.join(ta, "utils", "io.py"), [
        ("import torchaudio\n", io_shim, 1),
        ("torchaudio.info(", "_sf_info(", 1),
        ("torchaudio.load(", "_sf_load(", 1),
    ], marker="_sf_load")

    train_pairs = [
        ("import torch\nfrom torch import optim, nn\n",
         "import torch\n"
         "import torch.multiprocessing\n"
         "try:\n"
         '    torch.multiprocessing.set_start_method("fork", force=True)\n'
         "except RuntimeError:\n"
         "    pass\n"
         "from torch import optim, nn\n", 1),
        ("    from generate_samples import generate_samples\n",
         "    try:\n"
         "        from generate_samples import generate_samples\n"
         "    except ImportError:\n"
         "        generate_samples = None  # clips come from gen_voicevox.py\n", 1),
        ('        convert_onnx_to_tflite(os.path.join(config["output_dir"], config["model_name"] + ".onnx"),\n'
         '                               os.path.join(config["output_dir"], config["model_name"] + ".tflite"))',
         "        try:\n"
         '            convert_onnx_to_tflite(os.path.join(config["output_dir"], config["model_name"] + ".onnx"),\n'
         '                                   os.path.join(config["output_dir"], config["model_name"] + ".tflite"))\n'
         "        except Exception as e:\n"
         '            logging.warning(f"tflite conversion skipped: {e}")', 1),
    ]
    for split in ["positive_train", "negative_train", "positive_test", "negative_test"]:
        train_pairs.append((
            f"n_total=len(os.listdir({split}_output_dir)),",
            f'n_total=len(os.listdir({split}_output_dir))*config["augmentation_rounds"],', 1))
    patch(os.path.join(oww, "train.py"), train_pairs, marker="set_start_method")

    print("all patches OK")


if __name__ == "__main__":
    sys.exit(main())
