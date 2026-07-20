{
  lib,
  buildPythonPackage,
  fetchPypi,
  fetchurl,
  python,
  setuptools,
  onnxruntime,
  scipy,
  scikit-learn,
  numpy,
  tqdm,
  requests,
}:

let
  # 0.6.0 dropped the shared ONNX models from its dist, and download_models()
  # would fetch them into the read-only store path. Pre-seed the three the
  # ONNX path needs; upstream still publishes them under the v0.5.1 tag.
  modelBase = "https://github.com/dscripka/openWakeWord/releases/download/v0.5.1";
  models = {
    "silero_vad.onnx" = fetchurl {
      url = "${modelBase}/silero_vad.onnx";
      hash = "sha256-o16/Uv085fFGmyo2FY26dhvEe5c+ozgrMYbKFbH1ryg=";
    };
    "melspectrogram.onnx" = fetchurl {
      url = "${modelBase}/melspectrogram.onnx";
      hash = "sha256-uisOD4t7h1NposicsTNg/1O6xDbyiVzO2fR5+mXrF28=";
    };
    "embedding_model.onnx" = fetchurl {
      url = "${modelBase}/embedding_model.onnx";
      hash = "sha256-cNFkKQwdCV0dTuFJvF4AVDJQpzFrWfMdBWz/e9MHXB8=";
    };
  };
in
buildPythonPackage rec {
  pname = "openwakeword";
  version = "0.6.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-NoWNkPEYPjB0hVl6kSpOPDOEsU6pkj+D/q/658FWVWU=";
  };

  build-system = [ setuptools ];

  # tflite-runtime is a hard requires_dist with no py3.14 wheel. Safe to drop:
  # it is a lazy import in Model.__init__, unreachable on the ONNX path the
  # daemon uses.
  pythonRemoveDeps = [ "tflite-runtime" ];

  dependencies = [
    onnxruntime
    scipy
    scikit-learn
    numpy
    tqdm
    requests
  ];

  postInstall = ''
    dst=$out/${python.sitePackages}/openwakeword/resources/models
    mkdir -p "$dst"
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: file: ''cp ${file} "$dst/${name}"'') models
    )}
  '';

  pythonImportsCheck = [
    "openwakeword"
    "openwakeword.model"
  ];

  # Upstream tests need tflite-runtime, torch and network model downloads.
  doCheck = false;

  meta = {
    description = "Open-source wake word detection (ONNX runtime path)";
    homepage = "https://github.com/dscripka/openWakeWord";
    license = lib.licenses.asl20;
  };
}
