---
name: godot-ui
description: Делаешь интерфейс в Godot 4.7 — Control, контейнеры и якоря, фоны на весь экран, кнопки, тема, растягивание под разные разрешения, mouse_filter, фокус и навигация, CanvasLayer поверх мира, перевод текстов tr(). UI layout, theme, stretch, localization.
---

# Интерфейс в Godot 4.7

Интерфейс собирается в сцене из `Control` и контейнеров с якорями; внешний вид — через тему; тексты — через перевод. Сцены в целом — скилл `godot-scenes`, язык — `godot-gdscript`. Источники — `.claude/skills/THIRD_PARTY.md`.

## Сначала встроенное
| Нужно | Используй | Не делай |
|---|---|---|
| Раскладка | контейнеры + пресеты якорей | `position`/`size` под 1920×1080 в коде |
| Отступы | `MarginContainer` | ручные смещения |
| Ряд / столбец / сетка | `HBoxContainer`, `VBoxContainer`, `GridContainer`, `HFlowContainer` | расчёт координат в цикле |
| Сохранить пропорции | `AspectRatioContainer` | менять `size` в `_process` |
| Картинка на весь экран | `TextureRect` с якорем **Full Rect** | `Sprite2D` с ручным масштабом |
| Интерфейс поверх 2D/3D-мира | `CanvasLayer` с растянутым `Control` | `Control` прямо в мире — уедет с камерой |
| Фон панели | `PanelContainer` + `StyleBoxFlat` | `ColorRect` на `ColorRect` |
| Полоса прогресса | `ProgressBar` / `TextureProgressBar` | менять ширину `ColorRect` |
| Общий шрифт и стиль | тема проекта | `add_theme_*_override` везде |
| Окно подтверждения | `ConfirmationDialog` + `popup_centered()` | свои кнопки и Esc |
| Перетаскивание, подсказки | `_get_drag_data` / `_can_drop_data` / `_drop_data`, `tooltip_text` | свой расчёт в `_gui_input` |
| Видимые игроку тексты | ключ перевода / `tr()` | строки в коде |
| Подсказка клавиши | `InputMap.action_get_events` | жёстко «E» |

## Раскладка
Корень экрана — `Control` с пресетом **Full Rect**, внутри — вложенные контейнеры.
- Детьми контейнера управляет контейнер: ребёнок задаёт только `custom_minimum_size` (нижняя граница) и `size_flags_*`. `SIZE_EXPAND_FILL` (= 3) — занять остаток; пустой `Control` с ним — «пружина».
- Анимировать `position`/`size` ребёнка контейнера нельзя — контейнер перезапишет. Анимируй `scale`, `modulate`, `rotation` или оберни в простой `Control`. **4.7:** `offset_transform_*` — визуальный сдвиг/тряска без пересчёта раскладки.
- Центр масштаба — `pivot_offset`; с 4.6 — `pivot_offset_ratio = Vector2(0.5, 0.5)`.
- `Label` с `autowrap_mode` в сжатом контейнере схлопывается в 1 пиксель — дай ширину через `custom_minimum_size.x` или `SIZE_EXPAND_FILL`. **4.7:** `custom_maximum_size` ограничивает ширину (реплика: коротко — узко, длинно — перенос).
- Плавающий элемент из кода — тоже пресетом: `set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 32)`.

### Фон на весь экран
`TextureRect`: якорь **Full Rect**, `expand_mode = EXPAND_IGNORE_SIZE` (1), `stretch_mode`:
- `STRETCH_KEEP_ASPECT_COVERED` (6) — заполнить экран, лишнее обрезать (без полос);
- `STRETCH_KEEP_ASPECT_CENTERED` (5) — целиком, с полосами по краям;
- `STRETCH_SCALE` (0) — растянуть с искажением (обычно не надо).
Фон не должен ловить клики: `mouse_filter = MOUSE_FILTER_IGNORE`.

## Клики: mouse_filter
По умолчанию `STOP` (поглощает событие) у `Control`, `Panel`, `PanelContainer`, `ColorRect`, `Button`; `PASS` (передаёт родителю, если не обработал) у контейнеров и `TextureRect`; `IGNORE` (прозрачен) у `Label`.
- Растянутый корень интерфейса, декоративные `TextureRect`/`ColorRect`/`Panel`, иконки поверх кнопок — `IGNORE`, иначе они съедают клики по миру и кнопкам ниже.
- Клики и клавиши мира — в `_unhandled_input`: то, что обработал интерфейс, туда не дойдёт.
- Внутренняя логика контрола — `_gui_input` + `accept_event()`. Горячая клавиша кнопки — `BaseButton.shortcut`.
- 4.5+: выключить мышь у поддерева — `mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED`.

## Разные разрешения
`project.godot`, раздел `[display]`:
- `window/size/viewport_width` / `viewport_height` — базовое разрешение, под которое рисуем.
- `window/stretch/mode`: `canvas_items` — 2D и интерфейс рисуются в целевом разрешении, текст чёткий (подходит большинству игр, по умолчанию для новых проектов с 4.7); `viewport` — для пиксель-арта; `disabled` — без масштаба.
- `window/stretch/aspect`: `keep` — пропорции сохраняются, полосы по краям, интерфейсу проще; `expand` (по умолчанию с 4.7) — видно больше на широких экранах, интерфейс обязан держаться за края якорями; `keep_width` / `keep_height` — одна сторона фиксирована.
- Кроме `keep`, всё позиционируется только якорями и контейнерами — фиксированные координаты разъедутся.

## Тема
- Одна тема на проект: `[gui] theme/custom="res://.../main.tres"`, `theme/custom_font=...`. Все `Control` её наследуют.
- Варианты одного контрола (например, `DangerButton`) — type variation в теме + `theme_type_variation` у узла.
- Разовое отличие одного узла — `add_theme_*_override`. Меняешь стиль из `get_theme_stylebox()` — сначала `duplicate()`, иначе поменяется у всех.
- Обводка/тень одного `Label` — `label_settings` (ресурс `LabelSettings`, можно делить между метками; с 4.5 — несколько обводок и теней).

## Фокус и клавиатура
- Чтобы меню управлялось стрелками/геймпадом, после показа дай фокус первой кнопке: `_start_button.grab_focus.call_deferred()`. Скрытый контрол теряет фокус — при повторном показе снова.
- Встроенные `ui_*` действия (`ui_accept`, `ui_cancel`…) — для навигации по интерфейсу, не для игровой логики.
- Сложные экраны — явные `focus_neighbor_*` в инспекторе.

## Перевод текстов
Мы пишем на русском, английский — позже (решение #7). Чтобы перевод не стал переделкой:
- В `text` у `Label`/`Button` — ключ перевода (`MENU_START`): переводится автоматически. Строки из кода — `tr("KEY")`, с переменными — `tr("PICKED_UP").format({item = item_name})`.
- Множественное число — `tr_n()`, а не `if count == 1` (в русском три формы).
- Не переводить (имя игрока) — `auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED`.
- `tr()` в коде не обновляется при смене языка — пересчитай в `_notification` на `NOTIFICATION_TRANSLATION_CHANGED`.
- Проверка переполнения текста — псевдолокализация (`internationalization/pseudolocalization/use_pseudolocalization`).
- **Формат таблиц перевода выбирается в #4** — до этого ключи не вводим, в песочнице допустим обычный текст.

## Ловушки
- `Control`-ы с пиксельными координатами из кода разъезжаются при `expand` и других пропорциях.
- Растянутый корень интерфейса без `mouse_filter = IGNORE` съедает все клики.
- `@export`-узел в вручную написанном `.tscn` без `node_paths=` — `null` при запуске (см. `godot-scenes`).
- Меню без начального фокуса не реагирует на клавиатуру.

## Документация
- [Интерфейс](https://docs.godotengine.org/en/stable/tutorials/ui/index.html) · [Разные разрешения](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) · [Локализация](https://docs.godotengine.org/en/stable/tutorials/i18n/index.html)
