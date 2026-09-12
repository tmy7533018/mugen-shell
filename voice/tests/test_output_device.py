"""Which device playback opens.

Run from voice/:  python -m unittest discover -s tests
"""

import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from yura.tts import player  # noqa: E402


def _query(available):
    def query_devices(name, kind):
        if name not in available:
            raise ValueError(f"no device matching {name!r}")
        return {"name": name}
    return query_devices


class OutputDevice(unittest.TestCase):
    def setUp(self):
        player.output_device.cache_clear()
        self.addCleanup(player.output_device.cache_clear)

    def test_prefers_the_sound_server(self):
        # PortAudio's default is a raw ALSA device that ignores the selected sink.
        with mock.patch.object(player.sd, "query_devices", _query({"pipewire", "pulse", "default"})):
            self.assertEqual(player.output_device(), "pipewire")

    def test_falls_back_through_pulse_to_default(self):
        with mock.patch.object(player.sd, "query_devices", _query({"pulse", "default"})):
            self.assertEqual(player.output_device(), "pulse")
        player.output_device.cache_clear()
        with mock.patch.object(player.sd, "query_devices", _query({"default"})):
            self.assertEqual(player.output_device(), "default")

    def test_none_when_no_server_is_present(self):
        # None means "PortAudio's default", which is the only thing left to try.
        with mock.patch.object(player.sd, "query_devices", _query(set())):
            self.assertIsNone(player.output_device())


if __name__ == "__main__":
    unittest.main()
