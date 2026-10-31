"""Рисует заглушки для пазла «карта гонца»: две карты с яркими разными зонами (#60).

Запуск из корня репозитория: python tools/make_puzzle_pictures.py
У каждой зоны свой цвет и свои рисунки, чтобы по обрывку было видно, откуда он.
Нужен Pillow 13.0.0.
"""

import random
from pathlib import Path

from PIL import Image, ImageDraw

WORKSHOP_DIR = Path("sandbox/layers-2d/scenes/workshop")
SIZE = (780, 600)
SEA = (70, 135, 190, 255)
DARK_SEA = (45, 100, 160, 255)
GRASS = (135, 180, 90, 255)
FOREST = (60, 120, 65, 255)
SAND = (232, 200, 120, 255)
SNOW = (225, 228, 235, 255)
ROCK = (125, 110, 100, 255)
WHEAT = (235, 170, 60, 255)
RED = (190, 40, 50, 255)
INK = (55, 35, 25, 255)
WHITE = (245, 240, 225, 255)


def tree(draw, x, y):
    draw.polygon([(x, y - 34), (x - 24, y + 14), (x + 24, y + 14)], fill=FOREST)
    draw.rectangle((x - 5, y + 14, x + 5, y + 26), fill=INK)


def mountain(draw, x, y):
    draw.polygon([(x - 56, y + 50), (x, y - 52), (x + 56, y + 50)], fill=ROCK)
    draw.polygon([(x - 18, y - 18), (x, y - 52), (x + 18, y - 18)], fill=WHITE)


def castle(draw, x, y):
    draw.rectangle((x - 62, y - 40, x + 62, y + 50), fill=(165, 90, 70, 255))
    for tower in (-62, 0, 62):
        draw.polygon([(x + tower - 26, y - 40), (x + tower, y - 92), (x + tower + 26, y - 40)], fill=RED)
    draw.rectangle((x - 16, y + 8, x + 16, y + 50), fill=INK)


def ship(draw, x, y):
    draw.polygon([(x - 50, y), (x + 50, y), (x + 30, y + 26), (x - 30, y + 26)], fill=INK)
    draw.polygon([(x, y - 60), (x + 40, y - 8), (x, y - 8)], fill=WHITE)


def compass(draw, x, y):
    draw.ellipse((x - 54, y - 54, x + 54, y + 54), fill=WHITE, outline=INK, width=4)
    draw.polygon([(x, y - 46), (x + 12, y), (x - 12, y)], fill=RED)
    draw.polygon([(x, y + 46), (x + 12, y), (x - 12, y)], fill=INK)


def cross(draw, x, y):
    draw.line((x - 28, y - 28, x + 28, y + 28), fill=RED, width=13)
    draw.line((x + 28, y - 28, x - 28, y + 28), fill=RED, width=13)


def road(draw, points):
    for start, end in zip(points, points[1:]):
        for step in range(8):
            share = step / 8
            half = (step + 0.5) / 8
            draw.line(
                (
                    start[0] + (end[0] - start[0]) * share,
                    start[1] + (end[1] - start[1]) * share,
                    start[0] + (end[0] - start[0]) * half,
                    start[1] + (end[1] - start[1]) * half,
                ),
                fill=INK,
                width=7,
            )


def make_kingdom():
    """Королевство: море, лес, горы, поле, пустыня, у каждой зоны свой цвет."""
    picture = Image.new("RGBA", SIZE, GRASS)
    draw = ImageDraw.Draw(picture)
    draw.polygon([(0, 0), (300, 0), (240, 150), (90, 230), (0, 260)], fill=SEA)
    draw.polygon([(470, 0), (780, 0), (780, 240), (520, 200)], fill=SNOW)
    draw.polygon([(0, 390), (300, 360), (340, 600), (0, 600)], fill=(190, 215, 130, 255))
    draw.polygon([(520, 360), (780, 310), (780, 600), (560, 600)], fill=SAND)
    draw.polygon([(300, 360), (520, 360), (560, 600), (340, 600)], fill=WHEAT)
    draw.line([(240, 150), (320, 250), (290, 370), (430, 480), (470, 600)], fill=SEA, width=18)
    ship(draw, 110, 90)
    for x, y in [(540, 90), (640, 130), (720, 70)]:
        mountain(draw, x, y)
    for x, y in [(60, 440), (130, 490), (70, 540), (190, 450), (230, 540)]:
        tree(draw, x, y)
    castle(draw, 450, 280)
    compass(draw, 680, 490)
    cross(draw, 590, 560)
    road(draw, [(200, 300), (350, 330), (450, 330), (620, 300), (720, 380)])
    picture.save(WORKSHOP_DIR / "torn_map.png")


def make_islands():
    """Морская карта: острова разных цветов на воде, киты и корабли между ними."""
    picture = Image.new("RGBA", SIZE, SEA)
    draw = ImageDraw.Draw(picture)
    draw.rectangle((0, 300, 780, 600), fill=DARK_SEA)
    draw.ellipse((40, 40, 300, 240), fill=FOREST)
    draw.ellipse((470, 30, 740, 230), fill=SAND)
    draw.ellipse((60, 370, 320, 560), fill=(150, 90, 150, 255))
    draw.ellipse((480, 360, 740, 570), fill=SNOW)
    for x, y in [(120, 130), (190, 100), (220, 180)]:
        tree(draw, x, y)
    cross(draw, 600, 130)
    mountain(draw, 190, 470)
    castle(draw, 610, 480)
    ship(draw, 390, 130)
    compass(draw, 390, 470)
    draw.ellipse((330, 280, 450, 340), fill=INK)
    draw.polygon([(450, 310), (490, 280), (490, 340)], fill=INK)
    picture.save(WORKSHOP_DIR / "torn_islands.png")


def main() -> None:
    random.seed(11)
    make_kingdom()
    make_islands()


if __name__ == "__main__":
    main()
