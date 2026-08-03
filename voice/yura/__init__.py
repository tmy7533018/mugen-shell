"""Yura voice daemon.

Pipeline: mic -> VAD-endpointed capture -> whisper.cpp server (STT) ->
mugen-ai /chat -> TTS -> speakers.
"""
