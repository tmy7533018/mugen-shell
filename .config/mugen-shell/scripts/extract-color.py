#!/usr/bin/env python3
"""Extract dominant color from album art image.
Outputs RGB values as comma-separated string (e.g., "0.65,0.55,0.85")
"""

import sys
import os
import colorsys

DEFAULT_COLOR = (0.65, 0.55, 0.85)
TARGET_LUMINANCE = 0.5
DARK_COLOR_THRESHOLD = 0.15

try:
    from PIL import Image
    import numpy as np
    HAS_DEPENDENCIES = True
except ImportError:
    HAS_DEPENDENCIES = False


def get_default_color_string():
    return f"{DEFAULT_COLOR[0]:.3f},{DEFAULT_COLOR[1]:.3f},{DEFAULT_COLOR[2]:.3f}"


def convert_to_rgb(img):
    if img.mode == 'RGBA':
        background = Image.new('RGB', img.size, (255, 255, 255))
        background.paste(img, mask=img.split()[3])
        return background
    elif img.mode != 'RGB':
        return img.convert('RGB')
    return img


def calculate_luminance(r, g, b):
    """Weighted luminance using ITU-R BT.601 coefficients."""
    return 0.299 * r + 0.587 * g + 0.114 * b


def _adjust_dark_color(r, g, b, current_luminance, h, s, l):
    if current_luminance > 0:
        scale_factor = min(TARGET_LUMINANCE / current_luminance, 3.0)
        r_scaled = min(1.0, r * scale_factor)
        g_scaled = min(1.0, g * scale_factor)
        b_scaled = min(1.0, b * scale_factor)
    else:
        r_scaled, g_scaled, b_scaled = r, g, b

    _, s_scaled, _ = colorsys.rgb_to_hls(r_scaled, g_scaled, b_scaled)

    target_l = TARGET_LUMINANCE + 0.1
    l_final = min(0.85, target_l)
    s_final = max(0.5, min(1.0, s_scaled * 1.3))

    return l_final, s_final


def _adjust_bright_color(current_luminance, l, s):
    if current_luminance > TARGET_LUMINANCE * 1.2:
        l_final = max(TARGET_LUMINANCE - 0.1, l * 0.9)
    else:
        l_final = max(TARGET_LUMINANCE - 0.05, l)

    s_final = min(1.0, s * 1.05) if s < 0.9 else s

    return l_final, s_final


def _finalize_luminance(r, g, b):
    final_luminance = calculate_luminance(r, g, b)
    if abs(final_luminance - TARGET_LUMINANCE) > 0.15 and final_luminance > 0:
        adjust_factor = TARGET_LUMINANCE / final_luminance
        r = min(1.0, r * adjust_factor)
        g = min(1.0, g * adjust_factor)
        b = min(1.0, b * adjust_factor)
    return (r, g, b)


def ensure_min_lightness(r, g, b):
    if max(r, g, b) == 0:
        return DEFAULT_COLOR

    current_luminance = calculate_luminance(r, g, b)
    h, s, l = colorsys.rgb_to_hls(r, g, b)

    if current_luminance < TARGET_LUMINANCE:
        l_final, s_final = _adjust_dark_color(r, g, b, current_luminance, h, s, l)
    else:
        l_final, s_final = _adjust_bright_color(current_luminance, l, s)

    r_new, g_new, b_new = colorsys.hls_to_rgb(h, l_final, s_final)

    return _finalize_luminance(r_new, g_new, b_new)


def extract_dominant_color(image_path):
    if not HAS_DEPENDENCIES:
        raise ImportError("PIL and numpy are required")

    img = Image.open(image_path)
    img = convert_to_rgb(img)

    width, height = img.size

    # Sample the center 20% region
    sample_ratio = 0.2
    left = int(width * (0.5 - sample_ratio))
    top = int(height * (0.5 - sample_ratio))
    right = int(width * (0.5 + sample_ratio))
    bottom = int(height * (0.5 + sample_ratio))

    center_region = img.crop((left, top, right, bottom))
    pixels = np.array(center_region)

    avg_r = np.mean(pixels[:, :, 0]) / 255.0
    avg_g = np.mean(pixels[:, :, 1]) / 255.0
    avg_b = np.mean(pixels[:, :, 2]) / 255.0

    avg_r, avg_g, avg_b = ensure_min_lightness(avg_r, avg_g, avg_b)

    return (avg_r, avg_g, avg_b)


def validate_image_path(image_path):
    if not image_path:
        raise ValueError("Image path is empty")
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"File not found: {image_path}")
    if not os.path.isfile(image_path):
        raise ValueError(f"Path is not a file: {image_path}")


def main():
    if len(sys.argv) < 2:
        print("Usage: extract-color.py <image_path>", file=sys.stderr)
        print(get_default_color_string())
        sys.exit(1)

    image_path = sys.argv[1]

    try:
        validate_image_path(image_path)
    except (ValueError, FileNotFoundError) as e:
        print(str(e), file=sys.stderr)
        print(get_default_color_string())
        sys.exit(1)

    if not HAS_DEPENDENCIES:
        print("Warning: PIL and numpy not available, using default color", file=sys.stderr)
        print(get_default_color_string())
        sys.exit(1)

    try:
        r, g, b = extract_dominant_color(image_path)
        print(f"{r:.3f},{g:.3f},{b:.3f}")
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        print(get_default_color_string())
        sys.exit(1)


if __name__ == "__main__":
    main()
