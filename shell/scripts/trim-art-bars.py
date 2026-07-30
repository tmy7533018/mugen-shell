#!/usr/bin/env python3
"""Trim the solid letterbox/pillarbox bars some services pad cover art with.

Rewrites the image in place when bars are found. Exits 0 and leaves the file
untouched for anything it cannot improve, so callers can ignore the result.
"""

import sys

FLAT_TOLERANCE = 8
MATCH_TOLERANCE = 12
MAX_TRIM_RATIO = 0.45


def is_bar(extrema, reference):
    for (low, high), ref in zip(extrema, reference):
        if high - low > FLAT_TOLERANCE or abs((low + high) // 2 - ref) > MATCH_TOLERANCE:
            return False
    return True


def bar_width(image, span, box_at):
    reference = [(low + high) // 2 for low, high in image.crop(box_at(0)).getextrema()]
    offset = 0
    while offset < span and is_bar(image.crop(box_at(offset)).getextrema(), reference):
        offset += 1
    return offset


def bars(image):
    width, height = image.size

    left = bar_width(image, width, lambda x: (x, 0, x + 1, height))
    if left >= width:
        return 0, 0, 0, 0
    right = bar_width(image, width, lambda x: (width - 1 - x, 0, width - x, height))
    if left > width * MAX_TRIM_RATIO or right > width * MAX_TRIM_RATIO:
        left = right = 0

    inner = image.crop((left, 0, width - right, height))
    top = bar_width(inner, height, lambda y: (0, y, inner.width, y + 1))
    if top >= height:
        return left, right, 0, 0
    bottom = bar_width(inner, height, lambda y: (0, height - 1 - y, inner.width, height - y))
    if top > height * MAX_TRIM_RATIO or bottom > height * MAX_TRIM_RATIO:
        top = bottom = 0

    return left, right, top, bottom


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

    left, right, top, bottom = bars(rgb)
    if left + right + top + bottom == 0:
        return 0

    box = (left, top, width - right, height - bottom)
    if box[2] - box[0] < 8 or box[3] - box[1] < 8:
        return 0

    try:
        rgb.crop(box).save(path, format=image.format or "PNG")
    except Exception:
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
