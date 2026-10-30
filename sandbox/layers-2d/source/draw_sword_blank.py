# Рисует пиксельные иконки заготовки меча (холодную и нагретую) в стиле набора 496 RPG Icons (#37).
# Из корня репозитория: python sandbox/layers-2d/source/draw_sword_blank.py <холодная.png> <нагретая.png>
import math, sys
from PIL import Image

SIZE = 34
OUT_COLD, OUT_HOT = sys.argv[1], sys.argv[2]
START = (4.0, 4.0)
BLADE_END = 22.0
TANG_END = 30.5
AX = (1 / math.sqrt(2), 1 / math.sqrt(2))
PERP = (1 / math.sqrt(2), -1 / math.sqrt(2))
BLADE_HALF = 2.9
# Кованая полоса чуть неровная: сдвиг края по длине.
JITTER = [0.0, 0.2, 0.1, -0.2, 0.0, 0.2, 0.1, -0.1, 0.2, 0.0, -0.2, 0.1, 0.2, 0.0, -0.1, 0.1, 0.2, 0.0, -0.1, 0.1, 0.0, 0.1, 0.0]
TANG_HALF = 1.25
# Следы молота — тёмные точки на плоскости клинка (u, v).
MARKS = [(5.5, -0.6), (10.0, 0.6), (14.5, -0.4), (18.5, 0.5)]
PALETTES = {
    "cold": {"light": (212, 212, 222), "mid": (160, 158, 172), "dark": (114, 112, 128), "shadow": (82, 80, 96)},
    "hot": {"light": (255, 244, 170), "mid": (255, 178, 72), "dark": (232, 100, 36), "shadow": (168, 52, 24)},
}


def shade(u, v):
    if u < 0 or u > TANG_END:
        return None
    if u <= BLADE_END:
        half = BLADE_HALF + JITTER[min(int(u), len(JITTER) - 1)]
    else:
        half = TANG_HALF if u < TANG_END - 1.0 else TANG_HALF - 0.4
    if abs(v) > half:
        return None
    rel = v / half
    if u > BLADE_END:
        return "mid" if rel > 0 else "dark"
    if u < 1.0 or u > BLADE_END - 0.9:
        return "dark" if rel > -0.4 else "shadow"
    if any(abs(u - mu) < 0.8 and abs(v - mv) < 0.6 for mu, mv in MARKS):
        return "dark"
    if rel > 0.5:
        return "light"
    if rel > -0.3:
        return "mid"
    if rel > -0.75:
        return "dark"
    return "shadow"


def draw(palette, out):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    filled = {}
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x + 0.5 - START[0], y + 0.5 - START[1]
            tone = shade(dx * AX[0] + dy * AX[1], dx * PERP[0] + dy * PERP[1])
            if tone:
                filled[(x, y)] = palette[tone]
    for (x, y), color in filled.items():
        img.putpixel((x, y), color + (255,))
    for y in range(SIZE):
        for x in range(SIZE):
            near = any((x + ox, y + oy) in filled for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if (x, y) not in filled and near:
                img.putpixel((x, y), (0, 0, 0, 255))
    img.save(out)


draw(PALETTES["cold"], OUT_COLD)
draw(PALETTES["hot"], OUT_HOT)
