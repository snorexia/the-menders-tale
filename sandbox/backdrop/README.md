# Песочница «фон» (backdrop)

> Одноразовая, не игра и не архитектура — см. `sandbox/README.md`.

Вариант: **мокап целиком фоном** + кнопки перехода. Задача #12.

## Что внутри
- `scenes/counter/` — прилавок (фон `01-counter-customer.png`), кнопка «◀ В кузню».
- `scenes/forge/` — кузня (фон `02-forge-overview.png`), кнопка «К прилавку ▶».
- `common/scene_link_button.gd` — кнопка, открывающая другую сцену.

Без персонажей, мини-игр и сюжета — только внешний вид.

## Как открыть
1. Запусти Godot 4.7.2 → **Import** → выбери `sandbox/backdrop/project.godot` → **Import & Edit**.
2. Нажми **F5** (Run Project) — откроется прилавок. Кнопками переходи между сценами.

Агенту: проверить без окна — `"$GODOT_PATH" --headless --path sandbox/backdrop --quit-after 5`; скриншот сцены — `tools/godot_screenshot.gd` (см. `tools/README.md`).
