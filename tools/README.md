# Скрипты

Сохранённые скрипты для работы с инструментами (Blender, Meshy, Godot, Git), чтобы не писать одно и то же заново и не тратить токены ИИ.

| Скрипт | Что делает | Кто добавил |
|---|---|---|
| `godot_screenshot.gd` | Открывает сцену проекта Godot и сохраняет кадр в PNG — чтобы агент посмотрел на сцену одной картинкой. Запуск: `"$GODOT_PATH" --path sandbox/backdrop --script "$(pwd -W)/tools/godot_screenshot.gd" -- res://scenes/counter/counter.tscn <файл.png>` (без `--headless`, окно мелькнёт) | snorexia (#12) |
| `cut_layers.py` | Режет картинку (мокап) на слои по многоугольникам из JSON: каждый слой — PNG на весь холст, прозрачный вне многоугольника. Запуск: `python tools/cut_layers.py <слои.json> [--preview <контуры.png>]`, формат JSON — в начале скрипта. Нужен Pillow 13.0.0 | snorexia (#15) |
| `render_model.gd` | Рендерит 3D-модель (`.glb`/`.gltf`) в PNG с прозрачным фоном — модель дизайнера становится 2D-картинкой. Камера ортогональная, спереди, тёплый свет слева сверху. Запуск: `"$GODOT_PATH" --path <проект> --script "$(pwd -W)/tools/render_model.gd" -- <абс. путь к модели> <файл.png> [пикселей на метр] [поворот°]` (без `--headless`) | snorexia (#22) |
| `make_sword_stages.py` | Рисует стадии ковки мечей-заглушек поверх пустой наковальни, форма клинка — числами в скрипте. Запуск: `python tools/make_sword_stages.py`, печатает `strike_area` для `items.json`. Нужен Pillow 13.0.0 | Weh2 (#60) |
| `make_workbench_items.py` | Делает заглушки верстака: расписные сосуды, ремень из кожи сумки, иконки. Запуск: `python tools/make_workbench_items.py <папка 496_RPG_icons>`, ссылка на набор — в `docs/art/asset-log.md`. Нужен Pillow 13.0.0 | Weh2 (#60) |

Проверить проект Godot без окна: `"$GODOT_PATH" --headless --path <проект> --quit-after 5` — ошибки скриптов и сцен попадут в вывод. Стиль GDScript: `gdlint <папка>` (конфиг `gdlintrc` в корне).

Добавил скрипт — допиши строку в таблицу. Пути внутри скриптов — только относительные от корня репозитория.
