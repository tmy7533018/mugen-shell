"""Yura voice daemon.

Pipeline: mic -> wake word (openWakeWord) -> VAD-endpointed capture ->
whisper.cpp server (STT) -> mugen-ai /chat -> TTS -> speakers.
"""
