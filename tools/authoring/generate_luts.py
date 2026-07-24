#!/usr/bin/env python3
"""Generate color-correction LUT strips for the tower's Environment.

Outputs 256x16 PNGs (16 slices of 16x16: red = x, green = y, blue = slice)
to game/world/luts/. Godot imports them as Texture3D (slices/horizontal=16)
for Environment.adjustment_color_correction.

lut_neutral.png is the identity grade - keep it as the base layer for any
future hand-grading in GIMP. Every other entry in GRADES is a palette
candidate for the 80s-dark-fantasy look, defined by the parameters below.

Run from the repo root: python3 tools/authoring/generate_luts.py
"""

import colorsys
import math
import os

from PIL import Image

SIZE = 16
OUT_DIR = "game/world/luts"

# Each grade is one parameter set for apply_grade():
#   contrast     - S-curve strength on each channel (0 = off)
#   anchors      - hue anchors in degrees; every hue is pulled toward its
#                  nearest anchor (this is the palette-limiting operator)
#   strength     - how hard hues are pulled toward their anchor
#   stray_desat  - saturation loss for hues far from every anchor
#   shadow_tint / highlight_tint / tone_amount - split-toning
#   lift_color / lift - faded-film black lift
#   saturation   - global saturation multiplier applied last
GRADES = {
    # The chosen direction: candlelit amber over neutral blue-slate shadows,
    # dialed back from the bold A/B version toward a shippable subtlety.
    "ember": {
        "contrast": 0.15,
        "anchors": [36.0, 232.0],
        "strength": 0.35,
        "stray_desat": 0.4,
        "shadow_tint": (0.36, 0.40, 0.68),
        "highlight_tint": (1.0, 0.84, 0.62),
        "tone_amount": 0.20,
        "lift_color": (0.06, 0.07, 0.13),
        "lift": 0.02,
        "saturation": 1.0,
    },
}


def smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def luminance(r, g, b):
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def hue_distance(a, b):
    """Circular distance between two hues in [0, 1)."""
    d = abs(a - b) % 1.0
    return min(d, 1.0 - d)


def pull_hue(h, anchor, strength):
    """Move hue toward anchor along the short way around the wheel."""
    delta = (anchor - h) % 1.0
    if delta > 0.5:
        delta -= 1.0
    return (h + delta * strength) % 1.0


def compress_hues(r, g, b, anchors, strength, stray_desat):
    """Pull every hue toward its nearest anchor; desaturate stray hues.

    This is the operator that actually limits the palette: colors near an
    anchor keep their saturation, colors far from every anchor lose most
    of theirs instead of being forced to a wrong hue.
    """
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s < 1e-4:
        return r, g, b
    nearest = min(anchors, key=lambda a: hue_distance(h, a))
    dist = hue_distance(h, nearest)  # 0..0.5
    h = pull_hue(h, nearest, strength * smoothstep(0.5, 0.04, dist))
    s *= 1.0 - stray_desat * smoothstep(0.06, 0.25, dist)
    return colorsys.hsv_to_rgb(h, s, v)


def split_tone(r, g, b, shadow_tint, highlight_tint, amount):
    """Blend shadows/highlights toward their tints, preserving luminance."""
    lum = luminance(r, g, b)
    t = smoothstep(0.15, 0.85, lum)
    tint = [s + (h - s) * t for s, h in zip(shadow_tint, highlight_tint)]
    tint_lum = max(luminance(*tint), 1e-4)
    scaled = [c * lum / tint_lum for c in tint]
    return tuple(c + (tc - c) * amount for c, tc in zip((r, g, b), scaled))


def s_curve(c, amount):
    return c + (smoothstep(0.0, 1.0, c) - c) * amount


def lift_blacks(r, g, b, lift_color, lift):
    return tuple(c * (1.0 - lift) + lc * lift for c, lc in zip((r, g, b), lift_color))


def adjust_saturation(r, g, b, factor):
    if factor == 1.0:
        return r, g, b
    lum = luminance(r, g, b)
    return tuple(lum + (c - lum) * factor for c in (r, g, b))


def apply_grade(r, g, b, p):
    r, g, b = (s_curve(c, p["contrast"]) for c in (r, g, b))
    r, g, b = compress_hues(
        r, g, b,
        anchors=[a / 360.0 for a in p["anchors"]],
        strength=p["strength"], stray_desat=p["stray_desat"])
    r, g, b = split_tone(
        r, g, b, p["shadow_tint"], p["highlight_tint"], p["tone_amount"])
    r, g, b = lift_blacks(r, g, b, p["lift_color"], p["lift"])
    r, g, b = adjust_saturation(r, g, b, p["saturation"])
    return r, g, b


def write_lut(path, params):
    img = Image.new("RGB", (SIZE * SIZE, SIZE))
    for slice_index in range(SIZE):
        for y in range(SIZE):
            for x in range(SIZE):
                r, g, b = (x / (SIZE - 1), y / (SIZE - 1), slice_index / (SIZE - 1))
                if params is not None:
                    r, g, b = apply_grade(r, g, b, params)
                img.putpixel(
                    (slice_index * SIZE + x, y),
                    tuple(round(max(0.0, min(1.0, c)) * 255) for c in (r, g, b)))
    img.save(path)
    print("wrote", path)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    write_lut(os.path.join(OUT_DIR, "lut_neutral.png"), None)
    for name, params in GRADES.items():
        write_lut(os.path.join(OUT_DIR, "lut_%s.png" % name), params)


if __name__ == "__main__":
    main()
