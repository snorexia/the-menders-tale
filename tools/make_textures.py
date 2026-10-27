"""Рисует бесшовные пиксельные текстуры в стиле мокапов для песочницы sandbox/room-3d.

Палитра каждого материала снимается с участка мокапа, узор рисуется процедурно.
Запуск из корня репозитория:
    python tools/make_textures.py --out sandbox/room-3d/textures [--preview файл.png]
Нужен Pillow (см. tools/README.md).
"""

import argparse
import random
from pathlib import Path

from PIL import Image

FORGE_MOCKUP = "docs/reference/mockups/07-forge-empty.webp"
COUNTER_MOCKUP = "docs/reference/mockups/08-counter-empty.webp"

LOW_RES = 64  # размер тайла в «пикселях» рисунка
UPSCALE = 4  # во сколько раз увеличить без сглаживания: итог 256×256
SEED = 7

# материал: (мокап, участок left-top-right-bottom в пикселях мокапа)
PALETTE_SOURCES = {
    "stone": (COUNTER_MOCKUP, (780, 330, 1000, 520)),
    "floor": (COUNTER_MOCKUP, (560, 620, 1100, 720)),
    "wood": (COUNTER_MOCKUP, (20, 880, 260, 935)),
    "beam": (FORGE_MOCKUP, (1165, 100, 1200, 500)),
    "metal": (FORGE_MOCKUP, (700, 525, 900, 600)),
    "brick": (FORGE_MOCKUP, (240, 470, 330, 560)),
    "rug": (COUNTER_MOCKUP, (420, 800, 1250, 860)),
}

Color = tuple[int, int, int]


def sample_palette(mockup: str, box: tuple[int, int, int, int], count: int = 6) -> list[Color]:
    """Основные цвета участка, от тёмного к светлому."""
    quantized = Image.open(mockup).convert("RGB").crop(box).quantize(colors=count)
    raw = quantized.getpalette()[: count * 3]
    colors = [tuple(raw[i : i + 3]) for i in range(0, len(raw), 3)]
    return sorted(colors, key=_luminance)


def _luminance(color: Color) -> float:
    return 0.299 * color[0] + 0.587 * color[1] + 0.114 * color[2]


def _shade(color: Color, factor: float) -> Color:
    return tuple(max(0, min(255, round(channel * factor))) for channel in color)


def _value_noise(rng: random.Random, size: int, cells: int) -> list[list[float]]:
    """Плавный бесшовный шум 0..1: случайная сетка cells×cells, билинейно растянутая."""
    grid = [[rng.random() for _ in range(cells)] for _ in range(cells)]
    step = size / cells
    noise = []
    for y in range(size):
        gy, fy = divmod(y / step, 1)
        row = []
        for x in range(size):
            gx, fx = divmod(x / step, 1)
            x0, y0 = int(gx) % cells, int(gy) % cells
            x1, y1 = (x0 + 1) % cells, (y0 + 1) % cells
            top = grid[y0][x0] * (1 - fx) + grid[y0][x1] * fx
            bottom = grid[y1][x0] * (1 - fx) + grid[y1][x1] * fx
            row.append(top * (1 - fy) + bottom * fy)
        noise.append(row)
    return noise


def _pick(palette: list[Color], value: float) -> Color:
    index = min(len(palette) - 1, max(0, int(value * len(palette))))
    return palette[index]


def masonry(
    palette: list[Color],
    rng: random.Random,
    row_heights: list[int],
    width_range: tuple[int, int],
    contrast: float,
    is_rounded: bool = False,
) -> Image.Image:
    """Кладка: камни/кирпичи рядами, тёмный шов, светлый верх-лево, тень низ-право.

    is_rounded — срезать углы камней (бутовая кладка, а не кирпич).
    """
    size = LOW_RES
    image = Image.new("RGB", (size, size))
    pixels = image.load()
    mortar = _shade(palette[0], 0.7)
    noise = _value_noise(rng, size, 8)
    y_top = 0
    for height in row_heights:
        offset = rng.randrange(size)
        edges = [offset]
        while edges[-1] - offset < size - width_range[0]:
            edges.append(edges[-1] + rng.randint(*width_range))
        edges[-1] = offset + size  # последний камень замыкает ряд — бесшовно по X
        for left, right in zip(edges, edges[1:]):
            base = rng.uniform(0.25, 0.75)
            for y in range(y_top, y_top + height):
                for x in range(left, right):
                    local_x, local_y = x - left, y - y_top
                    from_right, from_bottom = right - left - 1 - local_x, height - 1 - local_y
                    corner = min(local_x, from_right) + min(local_y, from_bottom)
                    if local_x == 0 or local_y == 0 or (is_rounded and corner < 3):
                        color = mortar
                    else:
                        value = base + (noise[y % size][x % size] - 0.5) * contrast
                        value += rng.uniform(-0.12, 0.12)
                        if local_y == 1 or local_x == 1:
                            value += 0.25
                        elif local_y == height - 1 or local_x == right - left - 1:
                            value -= 0.3
                        color = _pick(palette, value)
                    pixels[x % size, y % size] = color
        y_top += height
    return image


def planks(palette: list[Color], rng: random.Random, plank_width: int) -> Image.Image:
    """Доски: вертикальные, волокна, тёмные щели, редкие сучки и гвозди."""
    size = LOW_RES
    image = Image.new("RGB", (size, size))
    pixels = image.load()
    gap = _shade(palette[0], 0.6)
    for left in range(0, size, plank_width):
        base = rng.uniform(0.3, 0.7)
        cut = rng.randrange(size)
        grain = [rng.uniform(-0.25, 0.25) for _ in range(plank_width)]
        for x in range(left, left + plank_width):
            for y in range(size):
                if x == left:
                    color = gap
                elif y == cut:
                    color = gap
                else:
                    wave = grain[(x - left + y // 9) % plank_width]
                    value = base + wave + rng.uniform(-0.08, 0.08)
                    if x == left + 1:
                        value += 0.2
                    color = _pick(palette, value)
                pixels[x, y] = color
        knot_x = left + rng.randint(4, plank_width - 4)
        knot_y = rng.randrange(size)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (-1, 0), (2, 1)):
            pixels[(knot_x + dx) % size, (knot_y + dy) % size] = _shade(palette[1], 0.8)
        for nail_y in ((cut + 2) % size, (cut - 3) % size):
            pixels[left + plank_width // 2, nail_y] = _shade(palette[-1], 0.7)
    return image


def metal(palette: list[Color], rng: random.Random) -> Image.Image:
    """Тёмный металл: пятна, царапины, ржавчина."""
    size = LOW_RES
    image = Image.new("RGB", (size, size))
    pixels = image.load()
    noise = _value_noise(rng, size, 6)
    rust = (110, 58, 32)
    for y in range(size):
        for x in range(size):
            value = noise[y][x] * 0.7 + rng.uniform(-0.1, 0.1)
            color = _pick(palette[:-1], value)
            if noise[(y * 3) % size][(x * 3) % size] > 0.82:
                color = rust
            pixels[x, y] = color
    scratch = _shade(palette[-1], 0.75)
    for _ in range(6):
        x, y = rng.randrange(size), rng.randrange(size)
        for step in range(rng.randint(2, 5)):
            pixels[(x + step) % size, (y + step // 2) % size] = scratch
    return image


def rug(palette: list[Color], rng: random.Random) -> Image.Image:
    """Коврик (не тайл): красное поле, кайма, ромбы. 128×64 до увеличения."""
    width, height = LOW_RES * 2, LOW_RES
    image = Image.new("RGB", (width, height))
    pixels = image.load()
    gold = (176, 128, 74)
    for y in range(height):
        for x in range(width):
            border = min(x, y, width - 1 - x, height - 1 - y)
            if border < 2:
                color = palette[0]
            elif border == 4:
                color = gold
            elif border < 7:
                color = palette[1]
            else:
                diamond = (abs((x % 16) - 8) + abs((y % 16) - 8)) == 6
                color = gold if diamond else _pick(palette[1:], 0.5 + rng.uniform(-0.3, 0.3))
            pixels[x, y] = color
    return image


def build_all(rng: random.Random) -> dict[str, Image.Image]:
    palettes = {name: sample_palette(*source) for name, source in PALETTE_SOURCES.items()}
    return {
        "stone_wall": masonry(palettes["stone"], rng, [12, 11, 14, 13, 14], (11, 24), 0.6, True),
        "floor_tiles": masonry(palettes["floor"], rng, [21, 22, 21], (20, 34), 0.35, True),
        "forge_brick": masonry(palettes["brick"], rng, [8] * 8, (14, 18), 0.4),
        "wood_planks": planks(palettes["wood"], rng, 16),
        "wood_beam": planks(palettes["beam"], rng, 32),
        "dark_metal": metal(palettes["metal"], rng),
        "rug": rug(palettes["rug"], rng),
    }


def save_preview(textures: dict[str, Image.Image], path: Path) -> None:
    """Все текстуры на одном листе — посмотреть одной картинкой."""
    cell = LOW_RES * UPSCALE // 2
    sheet = Image.new("RGB", (cell * 4, cell * 2), (20, 20, 20))
    for index, image in enumerate(textures.values()):
        thumb = image.resize((cell * image.width // image.height, cell), Image.Resampling.NEAREST)
        sheet.paste(thumb.crop((0, 0, cell, cell)), ((index % 4) * cell, (index // 4) * cell))
    sheet.save(path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, help="папка для PNG")
    parser.add_argument("--preview", help="сохранить лист со всеми текстурами")
    args = parser.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    textures = build_all(random.Random(SEED))
    for name, image in textures.items():
        size = (image.width * UPSCALE, image.height * UPSCALE)
        image.resize(size, Image.Resampling.NEAREST).save(out / f"{name}.png")
        print(f"{name}.png {size[0]}x{size[1]}")
    if args.preview:
        save_preview(textures, Path(args.preview))


if __name__ == "__main__":
    main()
