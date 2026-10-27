"""Режет картинку (мокап) на слои по многоугольникам из JSON.

Каждый слой — PNG размером с исходную картинку: внутри многоугольников —
пиксели исходника, снаружи — прозрачность. Поэтому слои совпадают друг
с другом без подгонки позиций. Слой без "polygons" — картинка целиком.

Формат JSON (пути — от корня репозитория):
    {
      "source": "docs/reference/mockups/08-counter-empty.webp",
      "feather": 2,
      "layers": [
        {"name": "counter_back"},
        {"name": "counter_front", "polygons": [[[0, 745], [1672, 745], [1672, 941], [0, 941]]]}
      ]
    }
"feather" — размытие края в пикселях, чтобы шов был мягче (0 — резкий край).
PNG слоёв сохраняются рядом с JSON: <папка JSON>/<name>.png.

Запуск из корня репозитория:
    python tools/cut_layers.py <слои.json> [--preview <файл.png>]
--preview рисует контуры многоугольников поверх исходника — проверить нарезку глазами.
Нужен Pillow (pip install pillow==13.0.0).
"""

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

PREVIEW_COLORS = ["#ff3030", "#30ff30", "#3080ff", "#ffff30", "#ff30ff", "#30ffff"]
PREVIEW_LINE_WIDTH = 3


def load_config(config_path: Path) -> dict:
    with config_path.open(encoding="utf-8") as config_file:
        return json.load(config_file)


def make_mask(size: tuple[int, int], polygons: list, feather: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    for polygon in polygons:
        draw.polygon([tuple(point) for point in polygon], fill=255)
    if feather > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(feather))
    return mask


def cut_layer(source: Image.Image, mask: Image.Image) -> Image.Image:
    # Цвет под полной прозрачностью обнуляем — иначе PNG весит как целая картинка.
    layer = source.copy()
    layer.putalpha(mask)
    empty = Image.new("RGBA", source.size, (0, 0, 0, 0))
    visible = mask.point(lambda value: 255 if value > 0 else 0)
    return Image.composite(layer, empty, visible)


def cut_layers(config_path: Path) -> None:
    config = load_config(config_path)
    source = Image.open(config["source"]).convert("RGBA")
    feather = config.get("feather", 0)

    for layer in config["layers"]:
        output_path = config_path.parent / f"{layer['name']}.png"
        polygons = layer.get("polygons")
        if polygons:
            image = cut_layer(source, make_mask(source.size, polygons, feather))
        else:
            image = source
        image.save(output_path, optimize=True)
        print(f"Слой сохранён: {output_path}")


def save_preview(config_path: Path, preview_path: Path) -> None:
    config = load_config(config_path)
    preview = Image.open(config["source"]).convert("RGB")
    draw = ImageDraw.Draw(preview)

    for index, layer in enumerate(config["layers"]):
        color = PREVIEW_COLORS[index % len(PREVIEW_COLORS)]
        for polygon in layer.get("polygons", []):
            points = [tuple(point) for point in polygon]
            draw.line(points + [points[0]], fill=color, width=PREVIEW_LINE_WIDTH)

    preview.save(preview_path)
    print(f"Превью сохранено: {preview_path}")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description="Режет мокап на слои по многоугольникам.")
    parser.add_argument("config", type=Path, help="JSON со слоями")
    parser.add_argument("--preview", type=Path, help="сохранить контуры поверх исходника")
    args = parser.parse_args()

    cut_layers(args.config)
    if args.preview:
        save_preview(args.config, args.preview)


if __name__ == "__main__":
    main()
