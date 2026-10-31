"""Рисует заглушки для пазлов верстака: витражи с контурами стёкол и порванную карту (#60).

Запуск из корня репозитория: python tools/make_puzzle_pictures.py
Витраж: `glass_<имя>.png`, рамка-подсказка `glass_<имя>_frame.png`, стёкла `glass_<имя>.json`.
Нужен Pillow 13.0.0.
"""

import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

WORKSHOP_DIR = Path("sandbox/layers-2d/scenes/workshop")
LEAD_COLOR = (24, 22, 24, 255)
FRAME_BACK = (20, 18, 22, 255)
LEAD_WIDTH = 7
SIZE = (640, 640)
PALETTE = [
    (190, 40, 50),
    (35, 80, 170),
    (235, 180, 45),
    (45, 140, 80),
    (120, 50, 150),
    (235, 120, 40),
    (70, 170, 190),
    (225, 225, 205),
]


def ring_sector(center, inner, outer, start, end, steps=8):
    points = []
    for step in range(steps + 1):
        angle = start + (end - start) * step / steps
        points.append((center[0] + math.cos(angle) * outer, center[1] + math.sin(angle) * outer))
    for step in range(steps, -1, -1):
        angle = start + (end - start) * step / steps
        points.append((center[0] + math.cos(angle) * inner, center[1] + math.sin(angle) * inner))
    return points


def make_rose():
    """Круглое окно-роза: середина и два кольца секторов."""
    center = (320, 320)
    polygons = [(ring_sector(center, 0.1, 80, 0, math.tau, 24)[:25], PALETTE[2])]
    for sector in range(6):
        start = sector * math.tau / 6
        polygons.append((ring_sector(center, 80, 200, start, start + math.tau / 6), PALETTE[sector % 2]))
    for sector in range(8):
        start = sector * math.tau / 8 + 0.2
        polygons.append((ring_sector(center, 200, 310, start, start + math.tau / 8), PALETTE[3 + sector % 4]))
    return polygons


def make_lancet():
    """Узкое окно с аркой: ромбы и верхушка."""
    left, right = 150, 490
    top, bottom = 150, 620
    middle = (left + right) / 2
    arch = [(middle + math.cos(a) * 170, top + math.sin(a) * 140) for a in [math.pi + i * math.pi / 16 for i in range(17)]]
    polygons = [(arch, PALETTE[2])]
    rows = 4
    row_height = (bottom - top) / rows
    for row in range(rows):
        y0 = top + row * row_height
        y1 = y0 + row_height
        polygons.append(([(left, y0), (middle, y0), (left, y1)], PALETTE[(row * 3) % 8]))
        polygons.append(([(middle, y0), (right, y0), (right, y1)], PALETTE[(row * 3 + 1) % 8]))
        polygons.append(([(middle, y0), (right, y1), (left, y1)], PALETTE[(row * 3 + 2) % 8]))
    return polygons


def make_sunburst():
    """Солнце ведьмы: лучи из точки сбоку, у каждого свой цвет."""
    center = (250, 380)
    corners = [(20, 20), (620, 20), (620, 620), (20, 620)]
    edge = []
    for from_point, to_point in zip(corners, corners[1:] + corners[:1]):
        for step in range(4):
            share = step / 4
            edge.append((from_point[0] + (to_point[0] - from_point[0]) * share, from_point[1] + (to_point[1] - from_point[1]) * share))
    polygons = []
    for index, point in enumerate(edge):
        following = edge[(index + 1) % len(edge)]
        polygons.append(([center, point, following], PALETTE[index % len(PALETTE)]))
    return polygons


def save_window(name, polygons, tint):
    glass = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    frame = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    glass_draw = ImageDraw.Draw(glass)
    frame_draw = ImageDraw.Draw(frame)
    for polygon, color in polygons:
        flat = [(round(x), round(y)) for x, y in polygon]
        glass_draw.polygon(flat, fill=(*color, 255))
        frame_color = (*[round(c * tint + 18 * (1 - tint)) for c in color], 255)
        frame_draw.polygon(flat, fill=frame_color)
    for polygon, _color in polygons:
        flat = [(round(x), round(y)) for x, y in polygon]
        flat.append(flat[0])
        glass_draw.line(flat, fill=LEAD_COLOR, width=LEAD_WIDTH, joint="curve")
        frame_draw.line(flat, fill=LEAD_COLOR, width=LEAD_WIDTH, joint="curve")
    glass.save(WORKSHOP_DIR / f"glass_{name}.png")
    frame.save(WORKSHOP_DIR / f"glass_{name}_frame.png")
    data = {"polygons": [[[round(x, 1), round(y, 1)] for x, y in polygon] for polygon, _color in polygons]}
    (WORKSHOP_DIR / f"glass_{name}.json").write_text(json.dumps(data), encoding="utf-8")


def parchment(size, seed):
    random.seed(seed)
    picture = Image.new("RGBA", size, (222, 200, 150, 255))
    draw = ImageDraw.Draw(picture)
    for _spot in range(320):
        x, y = random.randrange(size[0]), random.randrange(size[1])
        radius = random.randint(4, 28)
        shade = random.randint(190, 230)
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(shade, shade - 24, shade - 70, 255))
    return picture


def make_map():
    picture = parchment((780, 600), 11)
    draw = ImageDraw.Draw(picture)
    draw.polygon([(0, 0), (260, 0), (190, 110), (70, 190), (0, 230)], fill=(90, 150, 190, 255))
    draw.line([(190, 110), (310, 230), (280, 360), (420, 470), (480, 600)], fill=(70, 130, 180, 255), width=14)
    for x, y in [(520, 70), (590, 110), (660, 60), (720, 130)]:
        draw.polygon([(x - 50, y + 50), (x, y - 50), (x + 50, y + 50)], fill=(120, 105, 90, 255))
        draw.polygon([(x - 15, y - 20), (x, y - 50), (x + 15, y - 20)], fill=(240, 240, 240, 255))
    for x, y in [(90, 400), (140, 450), (70, 500), (170, 520), (220, 420)]:
        draw.ellipse((x - 32, y - 32, x + 32, y + 32), fill=(60, 120, 60, 255))
    draw.rectangle((440, 260, 560, 360), fill=(150, 80, 60, 255))
    draw.polygon([(430, 260), (500, 190), (570, 260)], fill=(190, 40, 50, 255))
    road = [(250, 560), (340, 420), (500, 360), (620, 300), (730, 380)]
    for start, end in zip(road, road[1:]):
        steps = 8
        for step in range(steps):
            a = step / steps
            b = (step + 0.5) / steps
            draw.line(
                [
                    (start[0] + (end[0] - start[0]) * a, start[1] + (end[1] - start[1]) * a),
                    (start[0] + (end[0] - start[0]) * b, start[1] + (end[1] - start[1]) * b),
                ],
                fill=(70, 40, 25, 255),
                width=8,
            )
    draw.line([(710, 500), (760, 560)], fill=(190, 40, 50, 255), width=12)
    draw.line([(760, 500), (710, 560)], fill=(190, 40, 50, 255), width=12)
    compass = (650, 470)
    draw.polygon([(compass[0], compass[1] - 50), (compass[0] + 14, compass[1]), (compass[0] - 14, compass[1])], fill=(40, 30, 25, 255))
    draw.polygon([(compass[0], compass[1] + 50), (compass[0] + 14, compass[1]), (compass[0] - 14, compass[1])], fill=(190, 40, 50, 255))
    picture.save(WORKSHOP_DIR / "torn_map.png")


def make_letter():
    picture = parchment((560, 700), 12)
    draw = ImageDraw.Draw(picture)
    random.seed(13)
    draw.rectangle((60, 60, 170, 180), fill=(150, 40, 50, 255))
    draw.polygon([(115, 80), (150, 160), (80, 160)], fill=(235, 190, 70, 255))
    y = 90
    while y < 560:
        left = 200 if y < 190 else 60
        x = left
        while x < 490:
            length = random.randint(20, 80)
            draw.line((x, y, min(x + length, 500), y), fill=(50, 35, 30, 255), width=7)
            x += length + 16
        y += 44
    draw.ellipse((340, 570, 480, 690), fill=(170, 30, 40, 255))
    draw.polygon([(410, 590), (440, 650), (380, 650)], fill=(110, 15, 25, 255))
    picture.save(WORKSHOP_DIR / "torn_letter.png")


def main() -> None:
    save_window("rose", make_rose(), 0.32)
    save_window("lancet", make_lancet(), 0.12)
    save_window("sun", make_sunburst(), 0.0)
    make_map()
    make_letter()


if __name__ == "__main__":
    main()
