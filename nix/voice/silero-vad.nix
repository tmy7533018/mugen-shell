{ fetchurl }:

# Endpointing needs this whether or not the wake word is on, so it is its own
# derivation: openWakeWord ships a copy, but depending on the package for it
# would drag scipy and scikit-learn (~200 MiB) into a push-to-talk-only build.
# Upstream publishes the shared ONNX models under the v0.5.1 tag.
fetchurl {
  name = "silero_vad.onnx";
  url = "https://github.com/dscripka/openWakeWord/releases/download/v0.5.1/silero_vad.onnx";
  hash = "sha256-o16/Uv085fFGmyo2FY26dhvEe5c+ozgrMYbKFbH1ryg=";
}
