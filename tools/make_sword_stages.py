"""Рисует стадии ковки разных мечей-заглушек поверх пустой наковальни (#60).

Форма клинка задаётся точками ниже, металл берётся с картинки дизайнера `anvil_stage_3.webp`.
Запуск из корня репозитория: python tools/make_sword_stages.py
Нужен Pillow 13.0.0. Печатает `strike_area` каждого меча для `common/items.json`.
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ANVIL_DIR = Path("sandbox/layers-2d/scenes/anvil")
EMPTY_PATH = ANVIL_DIR / "anvil_empty.webp"
METAL_SOURCE_PATH = ANVIL_DIR / "anvil_stage_3.webp"
HOT_METAL_BOX = (420, 400, 1090, 465)
TANG_METAL_BOX = (1150, 422, 1330, 450)
SCENE_SCALE = 1.1483
SUPERSAMPLE = 3
CENTER_Y = 432
STAGE_NAMES = ("bar", "rough", "blade")
# Как сильно меняется форма и насколько металл горячий на каждой стадии.
STAGE_SHAPE = (0.0, 0.55, 1.0)
STAGE_HEAT = (0.55, 0.8, 1.0)

# x_tip, x_guard — концы клинка; half_width — половина ширины у гарды;
# bend — изгиб вверх посередине; tang_end — конец хвостовика.
SWORDS = {
    "short": {"x_tip": 560, "x_guard": 1090, "half_width": 44, "bend": 0, "tang_end": 1260},
    "sabre": {"x_tip": 360, "x_guard": 1110, "half_width": 40, "bend": 70, "tang_end": 1290},
    "long": {"x_tip": 300, "x_guard": 1130, "half_width": 34, "bend": 0, "tang_end": 1370},
    "great": {"x_tip": 285, "x_guard": 1140, "half_width": 68, "bend": 0, "tang_end": 1440},
}
BAR_HALF_WIDTH = 46
BAR_LENGTH_SHARE = 0.72


def blade_polygon(sword: dict, shape: float) -> list[tuple[float, float]]:
    """Контур: от полосы (shape = 0) к готовому клинку с остриём (shape = 1)."""
    x_guard = sword["x_guard"]
    full_length = x_guard - sword["x_tip"]
    length = full_length * (BAR_LENGTH_SHARE + (1.0 - BAR_LENGTH_SHARE) * shape)
    half_width = BAR_HALF_WIDTH + (sword["half_width"] - BAR_HALF_WIDTH) * shape
    steps = 24
    top = []
    bottom = []
    for step in range(steps + 1):
        share = step / steps
        x = x_guard - length * share
        # Остриё сужается только на последней части клинка и только с формой.
        taper = 1.0 - shape * max(0.0, (share - 0.72) / 0.28) ** 1.6
        bend_y = -sword["bend"] * shape * (share**2)
        top.append((x, CENTER_Y + bend_y - half_width * taper))
        bottom.append((x, CENTER_Y + bend_y + half_width * taper))

    return top + bottom[::-1]


def tiled(source: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Заполнить холст кусками металла: зеркало, чтобы не было резких швов."""
    width, height = source.size
    canvas = Image.new("RGB", size)
    mirrored = source.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    for row in range(size[1] // height + 1):
        for column in range(size[0] // width + 1):
            tile = mirrored if row % 2 else source
            canvas.paste(tile, (column * width, row * height))

    return canvas


def mask_of(polygon: list[tuple[float, float]], size: tuple[int, int]) -> Image.Image:
    big = (size[0] * SUPERSAMPLE, size[1] * SUPERSAMPLE)
    mask = Image.new("L", big, 0)
    points = [(x * SUPERSAMPLE, y * SUPERSAMPLE) for x, y in polygon]
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return mask.resize(size, Image.Resampling.LANCZOS)


def paint(base: Image.Image, metal: Image.Image, mask: Image.Image) -> None:
    """Металл с тёмным контуром и тенью, как у заготовок дизайнера."""
    outline = mask.filter(ImageFilter.MaxFilter(5))
    shadow = outline.filter(ImageFilter.GaussianBlur(7))
    base.paste((10, 6, 5), (5, 9), ImageChops.multiply(shadow, Image.new("L", base.size, 150)))
    base.paste((24, 14, 12), (0, 0), outline)
    base.paste(metal, (0, 0), mask)


def make_stage(sword: dict, stage: int, empty: Image.Image, source: Image.Image) -> Image.Image:
    result = empty.copy()
    size = result.size
    tang_metal = tiled(source.crop(TANG_METAL_BOX), size)
    tang_y = 16
    x_guard = sword["x_guard"]
    tang = [
        (x_guard - 10, CENTER_Y - tang_y),
        (sword["tang_end"], CENTER_Y - tang_y),
        (sword["tang_end"], CENTER_Y + tang_y),
        (x_guard - 10, CENTER_Y + tang_y),
    ]
    paint(result, tang_metal, mask_of(tang, size))

    hot_metal = tiled(source.crop(HOT_METAL_BOX), size)
    # Холодный металл тёмный: смешиваем с цветом наковальни по стадии.
    cold = Image.new("RGB", size, (70, 52, 48))
    metal = Image.blend(cold, hot_metal, STAGE_HEAT[stage])
    paint(result, metal, mask_of(blade_polygon(sword, STAGE_SHAPE[stage]), size))
    return result


def main() -> None:
    empty = Image.open(EMPTY_PATH).convert("RGB")
    source = Image.open(METAL_SOURCE_PATH).convert("RGB")
    for sword_id, sword in SWORDS.items():
        for stage, stage_name in enumerate(STAGE_NAMES):
            path = ANVIL_DIR / f"sword_{sword_id}_{stage_name}.webp"
            make_stage(sword, stage, empty, source).save(path, quality=80, method=6)

        left = (sword["x_tip"] + 40) * SCENE_SCALE
        right = sword["x_guard"] * SCENE_SCALE
        top = (CENTER_Y - sword["bend"] * 0.5 - 24) * SCENE_SCALE
        bottom = (CENTER_Y + 24) * SCENE_SCALE
        area = [round(left), round(top), round(right - left), round(bottom - top)]
        print(sword_id, "strike_area", area)


if __name__ == "__main__":
    main()
