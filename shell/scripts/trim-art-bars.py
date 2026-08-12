#!/usr/bin/env python3
"""Trim the solid letterbox/pillarbox bars some services pad cover art with.

Only bars a centered 16:9 or square frame would leave are considered, so a flat
margin belonging to the art itself is never mistaken for padding.

Rewrites the image in place when bars are found. Exits 0 and leaves the file
untouched for anything it cannot improve, so callers can ignore the result.
"""

import os
import sys

FLAT_TOLERANCE = 16
MIN_BAR = 4
# The bar meets the art, and the bar running the other way, in bands of ringing that are not flat.
BAR_INSET_RATIO = 0.2
BAR_END_INSET_RATIO = 0.05
FRAME_ASPECTS = (16 / 9, 1.0)


def bar_boxes(width, height, aspect):
    """The pair of bars a centered frame of this aspect leaves, inset away from the art."""
    if width * 1.0 / height > aspect:
        bar = (width - round(height * aspect)) // 2
        deep = max(1, round(bar * BAR_INSET_RATIO))
        end = max(1, round(height * BAR_END_INSET_RATIO))
        return bar, [(0, end, bar - deep, height - end),
                     (width - bar + deep, end, width, height - end)]
    bar = (height - round(width / aspect)) // 2
    deep = max(1, round(bar * BAR_INSET_RATIO))
    end = max(1, round(width * BAR_END_INSET_RATIO))
    return bar, [(end, 0, width - end, bar - deep),
                 (end, height - bar + deep, width - end, height)]


def is_flat(image, box):
    if box[2] - box[0] < 1 or box[3] - box[1] < 1:
        return False
    return all(high - low <= FLAT_TOLERANCE for low, high in image.crop(box).getextrema())


def unpad(image):
    for aspect in FRAME_ASPECTS:
        width, height = image.size
        bar, boxes = bar_boxes(width, height, aspect)
        if bar < MIN_BAR or not all(is_flat(image, box) for box in boxes):
            continue
        if width * 1.0 / height > aspect:
            image = image.crop((bar, 0, width - bar, height))
        else:
            image = image.crop((0, bar, width, height - bar))
    return image


def main():
    if len(sys.argv) < 2:
        return 1
    path = sys.argv[1]

    try:
        from PIL import Image
    except ImportError:
        return 0

    try:
        image = Image.open(path)
        image.load()
        rgb = image.convert("RGB")
    except Exception:
        return 0

    width, height = rgb.size
    if width < 8 or height < 8:
        return 0

    trimmed = unpad(rgb)
    if trimmed.size == rgb.size:
        return 0

    staged = path + ".trim"
    try:
        trimmed.save(staged, format=image.format or "PNG")
    except Exception:
        try:
            os.remove(staged)
        except OSError:
            pass
        return 0

    os.replace(staged, path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
