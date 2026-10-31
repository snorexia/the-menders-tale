"""Делает картинки-заглушки для верстака: сосуды из CC0-картинки и ремень из кожи сумки (#60).

Запуск из корня репозитория:
python tools/make_workbench_items.py <путь к vasesandpots.png> <папка с иконками 496_RPG_icons>
vasesandpots.png — https://opengameart.org/content/stylized-vases-and-pots (CC0), не в репозитории.
Нужен Pillow 13.0.0.
"""

import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

WORKSHOP_DIR = Path("sandbox/layers-2d/scenes/workshop")
ICONS_DIR = Path("sandbox/layers-2d/common/icons")
BAG_PATH = WORKSHOP_DIR / "bag_repaired.png"
LEATHER_BOX = (620, 180, 1120, 420)
ICON_SIZE = 76
VESSEL_SCALE = 2.6
VESSEL_BRIGHTNESS = 1.45
# Рамки сосудов на исходной картинке, пиксели: ряд с ручками.
VESSELS = {
    "jug_pot": (240, 640, 470, 840),
    "jug_amphora": (469, 565, 612, 836),
    "jug_vase": (664, 565, 782, 836),
}
SWORD_ICONS = {
    "sword_short": "W_Sword010.png",
    "sabre": "W_Sword013.png",
    "sword_long": "W_Sword012.png",
    "greatsword": "W_Sword007.png",
}
BELT_SIZE = (1400, 220)
STRAP_MARGIN_Y = 40
RIP_X = 700
RIP_HALF_WIDTH = 34
BELT_DARKNESS = 0.42


def make_vessel(source: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    """Вырезать сосуд по цвету: фон зелёный, сосуд красно-оранжевый."""
    crop = source.crop(box).convert("RGB")
    red, green, _blue = crop.split()
    mask = ImageChops.subtract(red, green).point(lambda value: 255 if value > 4 else 0)
    mask = mask.filter(ImageFilter.MedianFilter(3))
    size = (round(crop.width * VESSEL_SCALE), round(crop.height * VESSEL_SCALE))
    bright = crop.point(lambda value: min(round(value * VESSEL_BRIGHTNESS), 255))
    result = bright.resize(size, Image.Resampling.LANCZOS).convert("RGBA")
    big_mask = mask.resize(size, Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(1.2))
    result.putalpha(big_mask.point(lambda value: 255 if value > 127 else 0))
    return result.crop(result.getbbox())


def make_icon(picture: Image.Image) -> Image.Image:
    icon = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
    fitted = picture.copy()
    fitted.thumbnail((ICON_SIZE, ICON_SIZE), Image.Resampling.LANCZOS)
    corner = ((ICON_SIZE - fitted.width) // 2, (ICON_SIZE - fitted.height) // 2)
    icon.paste(fitted, corner, fitted)
    return icon


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


def main() -> None:
    source = Image.open(sys.argv[1])
    icon_source = Path(sys.argv[2])
    vessels = {}
    for vessel_id, box in VESSELS.items():
        vessels[vessel_id] = make_vessel(source, box)
        vessels[vessel_id].save(WORKSHOP_DIR / f"{vessel_id}.png")

    make_icon(vessels["jug_amphora"]).save(ICONS_DIR / "jug_repaired_icon.png")
    broken = make_icon(vessels["jug_amphora"])
    gash = Image.new("L", broken.size, 255)
    ImageDraw.Draw(gash).line(
        [(18, 10), (34, 28), (26, 44), (46, 58), (40, 74)], fill=0, width=5
    )
    broken.putalpha(ImageChops.multiply(broken.getchannel("A"), gash))
    broken.save(ICONS_DIR / "jug_broken_icon.png")

    belt = make_belt()
    torn = tear_belt(belt)
    torn.save(WORKSHOP_DIR / "belt_torn.png")
    make_icon(belt).save(ICONS_DIR / "belt_repaired_icon.png")
    make_icon(torn).save(ICONS_DIR / "belt_torn_icon.png")

    for icon_name, source_name in SWORD_ICONS.items():
        found = next(icon_source.rglob(source_name))
        Image.open(found).convert("RGBA").save(ICONS_DIR / f"{icon_name}.png")


if __name__ == "__main__":
    main()
