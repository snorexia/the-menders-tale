"""Делает картинки-заглушки для верстака: расписные сосуды, ремень из кожи сумки, иконки (#60).

Запуск из корня репозитория: python tools/make_workbench_items.py <папка с иконками 496_RPG_icons>
Иконки: https://opengameart.org/content/496-pixel-art-icons-for-medievalfantasy-rpg (CC0), не в
репозитории. Сосуды нарисованы здесь: у каждого своя роспись, крупные и разные рисунки в разных
местах, чтобы по осколку было видно, откуда он. Нужен Pillow 13.0.0.
"""

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance

WORKSHOP_DIR = Path("sandbox/layers-2d/scenes/workshop")
ICONS_DIR = Path("sandbox/layers-2d/common/icons")
BAG_PATH = WORKSHOP_DIR / "bag_repaired.png"
LEATHER_BOX = (620, 180, 1120, 420)
ICON_SIZE = 76
SUPERSAMPLE = 2
SWORD_ICONS = {
    "sword_short": "W_Sword010.png",
    "sabre": "W_Sword013.png",
    "sword_long": "W_Sword012.png",
    "greatsword": "W_Sword007.png",
}
# Вещь: иконка из набора; сломанная — та же, тёмная и с трещиной.
REPAIR_ICONS = {"mail": ("A_Armor04.png", "torn"), "amulet": ("Ac_Medal04.png", "broken")}
BELT_SIZE = (1400, 220)
STRAP_MARGIN_Y = 40
RIP_X = 700
RIP_HALF_WIDTH = 34
BELT_DARKNESS = 0.42
BROKEN_BRIGHTNESS = 0.6
BROKEN_COLOR = 0.45

# Сосуды. profile — половина ширины по высоте (доли от 0 до 1); bands — цветные пояса сверху вниз:
# до какой доли высоты и цвет; motifs — рисунок, центр (доли холста), размер, цвет.
VESSELS = {
    "jug_pot": {
        "size": (640, 500),
        "profile": [(0, 0.34), (0.08, 0.3), (0.2, 0.42), (0.55, 0.47), (0.85, 0.36), (1, 0.24)],
        "handles": True,
        "bands": [
            (0.1, (40, 70, 130)),
            (0.34, (235, 222, 190)),
            (0.42, (190, 70, 45)),
            (0.8, (235, 222, 190)),
            (1, (40, 70, 130)),
        ],
        "motifs": [
            ("sun", 0.2, 0.25, 62, (230, 165, 30)),
            ("fish", 0.5, 0.22, 74, (40, 90, 170)),
            ("moon", 0.78, 0.25, 54, (90, 60, 130)),
            ("tree", 0.22, 0.62, 86, (50, 125, 60)),
            ("star", 0.5, 0.62, 70, (200, 60, 50)),
            ("flower", 0.78, 0.62, 72, (190, 60, 130)),
        ],
    },
    "jug_amphora": {
        "size": (420, 660),
        "profile": [(0, 0.3), (0.05, 0.2), (0.2, 0.18), (0.32, 0.44), (0.6, 0.42), (0.9, 0.18), (1, 0.22)],
        "handles": True,
        "bands": [
            (0.05, (25, 20, 20)),
            (0.2, (205, 105, 45)),
            (0.27, (25, 20, 20)),
            (0.55, (205, 105, 45)),
            (0.62, (25, 20, 20)),
            (0.88, (225, 150, 80)),
            (1, (25, 20, 20)),
        ],
        "motifs": [
            ("star", 0.5, 0.12, 40, (25, 20, 20)),
            ("bird", 0.3, 0.38, 62, (25, 20, 20)),
            ("sun", 0.68, 0.38, 54, (250, 225, 150)),
            ("tree", 0.3, 0.5, 44, (250, 225, 150)),
            ("fish", 0.68, 0.5, 50, (25, 20, 20)),
            ("moon", 0.5, 0.74, 54, (25, 20, 20)),
            ("flower", 0.5, 0.84, 34, (140, 40, 30)),
        ],
    },
    "jug_vase": {
        "size": (340, 660),
        "profile": [(0, 0.34), (0.07, 0.2), (0.3, 0.2), (0.48, 0.46), (0.72, 0.44), (1, 0.2)],
        "handles": False,
        "bands": [
            (0.08, (205, 160, 60)),
            (0.3, (20, 105, 110)),
            (0.36, (205, 160, 60)),
            (0.64, (235, 225, 195)),
            (0.7, (205, 160, 60)),
            (1, (20, 105, 110)),
        ],
        "motifs": [
            ("flower", 0.5, 0.2, 44, (235, 225, 195)),
            ("fish", 0.5, 0.46, 58, (20, 105, 110)),
            ("star", 0.26, 0.58, 38, (190, 60, 50)),
            ("moon", 0.74, 0.58, 38, (70, 60, 130)),
            ("tree", 0.32, 0.84, 58, (235, 225, 195)),
            ("sun", 0.7, 0.84, 44, (225, 180, 70)),
        ],
    },
}


def draw_motif(draw: ImageDraw.ImageDraw, name: str, x: float, y: float, r: float, color) -> None:
    """Крупные простые рисунки: их легко отличить на осколке."""
    if name == "sun":
        draw.ellipse((x - r * 0.55, y - r * 0.55, x + r * 0.55, y + r * 0.55), fill=color)
        for ray in range(12):
            angle = ray * math.tau / 12
            start = (x + math.cos(angle) * r * 0.65, y + math.sin(angle) * r * 0.65)
            draw.line((*start, x + math.cos(angle) * r, y + math.sin(angle) * r), fill=color, width=round(r * 0.14))
    elif name == "moon":
        draw.pieslice((x - r, y - r, x + r, y + r), 60, 300, fill=color)
    elif name == "star":
        points = []
        for corner in range(10):
            radius = r if corner % 2 == 0 else r * 0.42
            angle = corner * math.tau / 10 - math.pi / 2
            points.append((x + math.cos(angle) * radius, y + math.sin(angle) * radius))
        draw.polygon(points, fill=color)
    elif name == "fish":
        draw.ellipse((x - r, y - r * 0.5, x + r * 0.55, y + r * 0.5), fill=color)
        draw.polygon([(x + r * 0.4, y), (x + r, y - r * 0.55), (x + r, y + r * 0.55)], fill=color)
    elif name == "tree":
        draw.rectangle((x - r * 0.13, y, x + r * 0.13, y + r), fill=color)
        draw.polygon([(x, y - r), (x - r * 0.75, y + r * 0.35), (x + r * 0.75, y + r * 0.35)], fill=color)
    elif name == "bird":
        draw.polygon([(x - r, y - r * 0.7), (x, y), (x + r, y - r * 0.7), (x + r * 0.2, y + r * 0.5), (x - r * 0.2, y + r * 0.5)], fill=color)
    elif name == "flower":
        for petal in range(6):
            angle = petal * math.tau / 6
            px = x + math.cos(angle) * r * 0.6
            py = y + math.sin(angle) * r * 0.6
            draw.ellipse((px - r * 0.38, py - r * 0.38, px + r * 0.38, py + r * 0.38), fill=color)


def half_width(profile: list, share: float) -> float:
    """Плавная ширина сосуда между точками профиля."""
    for (from_y, from_w), (to_y, to_w) in zip(profile, profile[1:]):
        if share <= to_y:
            part = (share - from_y) / (to_y - from_y)
            part = part * part * (3 - 2 * part)
            return from_w + (to_w - from_w) * part
    return profile[-1][1]


def make_vessel(vessel: dict) -> Image.Image:
    width = vessel["size"][0] * SUPERSAMPLE
    height = vessel["size"][1] * SUPERSAMPLE
    paint = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(paint)
    top = 0
    for band_end, color in vessel["bands"]:
        bottom = round(band_end * height)
        draw.rectangle((0, top, width, bottom), fill=color)
        top = bottom

    for name, x_share, y_share, size, color in vessel["motifs"]:
        draw_motif(draw, name, x_share * width, y_share * height, size * SUPERSAMPLE, color)

    # Объём: края темнее, левая сторона светлее — так видно, с какого боку осколок.
    shade = Image.new("L", (width, height))
    for x in range(width):
        share = x / width
        value = 255 - round(150 * abs(share * 2 - 1) ** 2.2) - round(36 * share)
        ImageDraw.Draw(shade).line((x, 0, x, height), fill=max(value, 0))
    paint = ImageChops.multiply(paint, Image.merge("RGB", (shade, shade, shade)))

    mask = Image.new("L", (width, height), 0)
    mask_draw = ImageDraw.Draw(mask)
    left = []
    right = []
    for row in range(0, height + 1, 4):
        half = half_width(vessel["profile"], row / height) * width
        left.append((width / 2 - half, row))
        right.append((width / 2 + half, row))
    mask_draw.polygon(left + right[::-1], fill=255)
    if vessel["handles"]:
        for side in (-1, 1):
            center_x = width / 2 + side * width * 0.42
            box_h = height * 0.11
            box = (center_x - width * 0.09, height * 0.13, center_x + width * 0.09, height * 0.13 + box_h * 2)
            mask_draw.arc(box, 0, 360, fill=255, width=round(width * 0.035))

    result = paint.convert("RGBA")
    result.putalpha(mask)
    result = result.resize(vessel["size"], Image.Resampling.LANCZOS)
    return result.crop(result.getbbox())


def make_icon(picture: Image.Image) -> Image.Image:
    icon = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
    fitted = picture.copy()
    fitted.thumbnail((ICON_SIZE, ICON_SIZE), Image.Resampling.LANCZOS)
    corner = ((ICON_SIZE - fitted.width) // 2, (ICON_SIZE - fitted.height) // 2)
    icon.paste(fitted, corner, fitted)
    return icon


def make_broken_icon(icon: Image.Image) -> Image.Image:
    """Сломанная вещь: тусклее, темнее, поперёк трещина."""
    width, height = icon.size
    colors = ImageEnhance.Color(icon.convert("RGB")).enhance(BROKEN_COLOR)
    colors = ImageEnhance.Brightness(colors).enhance(BROKEN_BRIGHTNESS).convert("RGBA")
    gash = Image.new("L", icon.size, 255)
    points = [(0.24, 0.1), (0.46, 0.38), (0.34, 0.58), (0.6, 0.76), (0.52, 1.0)]
    scaled = [(x * width, y * height) for x, y in points]
    ImageDraw.Draw(gash).line(scaled, fill=0, width=max(round(width / 16), 2))
    colors.putalpha(ImageChops.multiply(icon.getchannel("A"), gash))
    return colors


def make_belt() -> Image.Image:
    """Ремень: кожа сумки дизайнера, строчка, пряжка, дырки на конце."""
    width, height = BELT_SIZE
    leather = Image.open(BAG_PATH).convert("RGB").crop(LEATHER_BOX).resize((width, height))
    # На столе того же цвета светлая кожа теряется: темним её.
    belt = leather.point(lambda value: round(value * BELT_DARKNESS)).convert("RGBA")
    mask = Image.new("L", BELT_SIZE, 0)
    mask_draw = ImageDraw.Draw(mask)
    strap = (70, STRAP_MARGIN_Y, width - 8, height - STRAP_MARGIN_Y)
    mask_draw.rounded_rectangle(strap, radius=50, fill=255)
    belt.putalpha(mask)

    draw = ImageDraw.Draw(belt)
    top = STRAP_MARGIN_Y + 14
    bottom = height - STRAP_MARGIN_Y - 14
    for x in range(110, width - 60, 34):
        draw.line((x, top, x + 18, top), fill=(226, 180, 110, 255), width=4)
        draw.line((x, bottom, x + 18, bottom), fill=(226, 180, 110, 255), width=4)

    for x in range(width - 300, width - 60, 60):
        draw.ellipse((x - 9, height / 2 - 9, x + 9, height / 2 + 9), fill=(22, 12, 8, 255))

    gold = (205, 160, 70, 255)
    draw.rounded_rectangle((16, 22, 140, height - 22), radius=14, outline=gold, width=16)
    draw.line((78, height / 2, 170, height / 2), fill=gold, width=12)
    return belt


def tear_belt(belt: Image.Image) -> Image.Image:
    """Разорвать ремень посередине: рваная прозрачная щель."""
    random.seed(60)
    height = belt.height
    left = []
    right = []
    for y in range(0, height + 1, 14):
        left.append((RIP_X - RIP_HALF_WIDTH + random.randint(-22, 22), y))
        right.append((RIP_X + RIP_HALF_WIDTH + random.randint(-22, 22), y))

    gap = Image.new("L", belt.size, 255)
    ImageDraw.Draw(gap).polygon(left + right[::-1], fill=0)
    result = belt.copy()
    result.putalpha(ImageChops.multiply(result.getchannel("A"), gap))
    return result


def find_icon(icon_source: Path, name: str) -> Image.Image:
    return Image.open(next(icon_source.rglob(name))).convert("RGBA")


def main() -> None:
    icon_source = Path(sys.argv[1])
    vessels = {}
    for vessel_id, vessel in VESSELS.items():
        vessels[vessel_id] = make_vessel(vessel)
        vessels[vessel_id].save(WORKSHOP_DIR / f"{vessel_id}.png")

    jug_icon = make_icon(vessels["jug_amphora"])
    jug_icon.save(ICONS_DIR / "jug_repaired_icon.png")
    make_broken_icon(jug_icon).save(ICONS_DIR / "jug_broken_icon.png")

    belt = make_belt()
    torn = tear_belt(belt)
    torn.save(WORKSHOP_DIR / "belt_torn.png")
    make_icon(belt).save(ICONS_DIR / "belt_repaired_icon.png")
    make_icon(torn).save(ICONS_DIR / "belt_torn_icon.png")

    for icon_name, (source_name, broken_word) in REPAIR_ICONS.items():
        icon = find_icon(icon_source, source_name)
        icon.save(ICONS_DIR / f"{icon_name}_repaired_icon.png")
        make_broken_icon(icon).save(ICONS_DIR / f"{icon_name}_{broken_word}_icon.png")

    for icon_name, source_name in SWORD_ICONS.items():
        find_icon(icon_source, source_name).save(ICONS_DIR / f"{icon_name}.png")


if __name__ == "__main__":
    main()
