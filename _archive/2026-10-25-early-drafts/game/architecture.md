# Архитектура (Godot 4)

> Черновик. Проект Godot ещё не создан — это план, как его разложить, чтобы трое не мешали друг другу.

## Главный принцип: данные отдельно от сцен
Сценарист и дизайнер не должны открывать `.tscn`, чтобы добавить клиента или предмет. Всё содержимое — в текстовых файлах данных, которые читает код.

```
game/
  project.godot
  scenes/
    counter/         Прилавок (главный экран)
    forge/           Кузня
    workbench/       Верстак
    minigames/       Каждая мини-игра — отдельная сцена
    ui/              Общие элементы: кнопки, карточки, панель инструментов
  scripts/
    core/            GameState, Economy, OrderManager (автозагрузки)
    minigames/
  data/              ← правят сценарист и дизайнер, не код
    items/           Предметы: *.json
    orders/          Заказы клиентов: *.json
    customers/       Клиенты: *.json
    dialogue/        Диалоги
  assets/
    models/          .glb из Blender
    textures/ ui/ backgrounds/ portraits/ audio/ fonts/
```

## Правила, чтобы не конфликтовать
- **Одна сцена — один хозяин в моменте.** `.tscn` плохо сливаются в Git. Кто правит сцену, указывает это в Issue.
- Мелкие сцены вместо одной огромной: каждая мини-игра, каждая панель интерфейса — отдельный файл.
- Папка `.godot/` не коммитится (кэш).
- Модели импортируются как `.glb`; исходник `.blend` лежит в `art-source/`.

## Пример данных заказа
```json
{
  "id": "aldric_broken_sword",
  "customer": "sir_aldric",
  "item": "longsword",
  "station": "forge",
  "steps": ["straighten_blade", "weld_break", "sharpen"],
  "reward": 120,
  "intro_dialogue": "aldric_intro_01"
}
```
