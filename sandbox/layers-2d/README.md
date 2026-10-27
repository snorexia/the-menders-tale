# Песочница «2D-слои» (layers-2d)

> Одноразовая, не игра и не архитектура — см. `sandbox/README.md`.

Вариант: **мокап, разрезанный на слои**, слои слегка сдвигаются за мышью (параллакс — ближнее двигается сильнее дальнего), плюс мерцающий свет и огонь. Задача #15.

## Что внутри
- `scenes/counter/` — прилавок (мокап `08-counter-empty.webp`): 3 слоя, 2 фонаря и 3 свечи мерцают, кнопка «◀ В кузню».
- `scenes/forge/` — кузня (мокап `07-forge-empty.webp`): 3 слоя, 2 лампы мерцают, огонь горна (пламя, искры, свет), кнопка «К прилавку ▶».
- Слои сцены: `*_back` (весь мокап) → `*_sides` (мебель по бокам, горн) → `*_front` (прилавок, наковальня, ящики). Каждый — PNG на весь холст, прозрачный вне вырезанной части.
- `scenes/<сцена>/<сцена>_layers.json` — многоугольники слоёв в пикселях мокапа (из них `tools/cut_layers.py` делает PNG).
- `common/mouse_parallax_camera.gd` — камера чуть сдвигается за мышью, слои `Parallax2D` догоняют её с разной силой (`scroll_scale`: 0.25 / 0.6 / 1).
- `common/flicker_light.gd` — свет (`PointLight2D`), яркость и размер которого гуляют по шуму.
- `common/light_glow.tres` — мягкое круглое пятно: текстура для света и частиц огня.
- `common/scene_link_button.gd` — кнопка, открывающая другую сцену (копия из `backdrop`).

## Как открыть
1. Запусти Godot 4.7.2 → **Import** → выбери `sandbox/layers-2d/project.godot` → **Import & Edit**.
2. Нажми **F5** (Run Project) — откроется прилавок. Поводи мышью, кнопками переходи между сценами.

## Что подкрутить
- **Сила параллакса** — у узла `Camera` в сцене: `Max Offset` (сейчас 12×6 px) и `Follow Speed`; глубина слоёв — `Scroll Scale` у `BackLayer` / `SidesLayer`.
- **Темнота сцены** — цвет узла `Darkness` (`CanvasModulate`).
- **Мерцание** — у каждого света: `Strength`, `Scale Strength`, `Speed`; яркость — `Energy`, размер пятна — `Texture Scale`.
- **Огонь** — узлы `Flames` и `Sparks` в кузне (`CPUParticles2D`).

## Как перерезать слои
Поправь многоугольники в `scenes/<сцена>/<сцена>_layers.json` и из корня репозитория запусти:
```
python tools/cut_layers.py sandbox/layers-2d/scenes/counter/counter_layers.json --preview counter_preview.png
```
`--preview` сохранит мокап с контурами слоёв — проверить нарезку глазами (файл не коммить).

Агенту: проверить без окна — `"$GODOT_PATH" --headless --path sandbox/layers-2d --quit-after 5`; скриншот сцены — `tools/godot_screenshot.gd` (см. `tools/README.md`).
