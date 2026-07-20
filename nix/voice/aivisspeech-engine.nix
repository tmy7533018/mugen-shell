{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  _7zz,
  zlib,
}:

# The official Linux build is a PyInstaller onedir bundle (everything under
# _internal/), shipped as a split 7-Zip. We just unpack it and let
# autoPatchelf rewrite the interpreter + RPATH of `run` and the bundled .so
# set so it runs without the nix-ld shim.
stdenv.mkDerivation rec {
  pname = "aivisspeech-engine";
  version = "1.2.0";

  src = fetchurl {
    url = "https://github.com/Aivis-Project/AivisSpeech-Engine/releases/download/${version}/AivisSpeech-Engine-Linux-x64-${version}.7z.001";
    hash = "sha256-pLHMeQ6aFSLYgOBj14jqLDPfkJ6I52TYrloX41l7FbU=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    _7zz
  ];

  # `run` only misses libz; the bundled onnxruntime/soundfile/etc. pull
  # libstdc++/libgcc_s, so give autoPatchelf the cc runtime too.
  buildInputs = [
    stdenv.cc.cc.lib
    zlib
  ];

  # The bundled onnxruntime-gpu provider references CUDA/cuDNN/TensorRT libs
  # (and _tkinter wants Tcl/Tk) that don't exist here. Only reached in GPU
  # mode / the unused GUI, so they are ignored by name — a wildcard would also
  # swallow a genuinely required lib appearing in a future bundle and turn a
  # build error into a runtime crash loop.
  autoPatchelfIgnoreMissingDeps = [
    "libcublas.so.12"
    "libcublasLt.so.12"
    "libcudart.so.12"
    "libcudnn.so.9"
    "libcufft.so.11"
    "libcurand.so.10"
    "libnvinfer.so.10"
    "libnvonnxparser.so.10"
    "libtcl9.0.so"
    "libtcl9tk9.0.so"
  ];

  unpackPhase = ''
    runHook preUnpack
    7zz x -y "$src"
    runHook postUnpack
  '';

  sourceRoot = "Linux-x64";

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/opt/aivisspeech-engine" "$out/bin"
    cp -r . "$out/opt/aivisspeech-engine/"
    ln -s "$out/opt/aivisspeech-engine/run" "$out/bin/aivisspeech-engine"
    runHook postInstall
  '';

  # PyInstaller bundle: don't let Nix strip the packed .so set.
  dontStrip = true;

  meta = {
    description = "AivisSpeech TTS engine (VOICEVOX-compatible API), prebuilt Linux bundle";
    homepage = "https://github.com/Aivis-Project/AivisSpeech-Engine";
    license = lib.licenses.lgpl3Only;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "aivisspeech-engine";
  };
}
