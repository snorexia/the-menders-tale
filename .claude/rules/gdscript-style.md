---
paths: ["**/*.gd"]
---

# Стиль GDScript

Основа — [официальный гайд Godot](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) и [гайд GDQuest](https://gdquest.gitbook.io/gdquests-guidelines/godot-gdscript-guidelines). Ниже — что обязательно у нас.

## Именование
| Что | Как | Пример |
|---|---|---|
| Файлы и папки | `snake_case` | `repair_order.gd`, `forge/` |
| Классы (`class_name`), узлы в сцене | `PascalCase` | `RepairOrder`, `AnvilArea` |
| Функции, переменные, параметры | `snake_case` | `start_repair()`, `coin_count` |
| Приватные функции и переменные | `_snake_case` | `_update_heat()`, `_heat` |
| Константы, значения enum | `CONSTANT_CASE` | `MAX_HEAT`, `State.BROKEN` |
| Enum (тип) | `PascalCase`, ед. число | `enum State { WHOLE, BROKEN }` |
| Сигналы | `snake_case`, прошедшее время | `item_repaired`, `order_finished` |

- Файл скрипта с `class_name` называется как класс: `RepairOrder` → `repair_order.gd`.
- Скрипт и сцена называются по корневому узлу: `forge.tscn` + `forge.gd`, корень `Forge`.
- Булевы переменные и функции: `is_`, `can_`, `has_` (`is_broken`, `can_repair()`). Не `check_x()` — размыто и прячет побочные эффекты.
- Функции, которые могут не выполниться: `try_x() -> bool`.
- Обработчики сигналов: `_on_<узел>_<сигнал>` (`_on_anvil_area_body_entered`); на себя — `_on_<сигнал>`.
- Начало и конец действия: `_started` / `_finished` (`repair_started`).
- Полные слова, без сокращений: `character_position`, не `char_pos`.
- Без тавтологии: `inventory.add(item)`, не `inventory.add_item_to_inventory(item)`.
- Без размытых имён: `Manager`, `Helper`, `Controller` — назови по ответственности (`OrderQueue`, `CoinWallet`).
- Множественное число для коллекций: `orders` — массив, `order` — один.

## Порядок в файле
```
@tool / @icon
class_name RepairOrder
extends Node
## Документация класса.

signal item_repaired(item: Item)
enum State { WHOLE, BROKEN }
const MAX_HEAT := 100
@export var item: Item
var coin_count: int = 0
var _heat: float = 0.0
@onready var _anvil: Area2D = $AnvilArea

func _init() -> void: ...
func _ready() -> void: ...
func _process(delta: float) -> void: ...

func start_repair() -> void: ...       # публичные методы
func _update_heat() -> void: ...       # приватные методы
```
Внутри группы — сначала публичное, потом приватное.

## Типизация — обязательна
- Тип у каждой переменной, параметра и возврата: `var heat: float`, `func repair(item: Item) -> bool`.
- `:=` — только когда тип очевиден из той же строки: `var timer := Timer.new()`, `const MAX_HEAT := 100`.
- Типизированные массивы и словари: `var orders: Array[Order] = []`.
- Явный тип, если функция возвращает `Variant`: `var order: Order = orders.pop_back()`.
- Для узлов — тип в объявлении: `@onready var _anvil: Area2D = $AnvilArea`.

## Логика
- Отрицание — словом `not`: `if not is_broken:`. Не `!` и не `== false`.
- Логические операторы — `and`, `or`, `not`, не `&&`, `||`.
- `return` — только как ранний выход (guard) в начале или в конце функции, не в середине.
  ```
  func repair(item: Item) -> void:
  	if not item.is_broken:
  		return
  	...
  ```
- `null` — по минимуму. Лучше осмысленное значение: `Vector2.ZERO`, пустой массив, новый объект.
- Никаких магических чисел: выноси в `const` с понятным именем (`const PERFECT_HIT_WINDOW := 0.15`). Допустимы `0`, `1`, `-1`, когда смысл очевиден.
- Повторяющийся блок кода — в функцию.
- Без вычислений внутри выводимого текста: сначала посчитай в переменную, потом выводи.

## Связи между частями игры
- **Вызов вниз, сигнал вверх**: родитель вызывает методы детей; дети сообщают родителю сигналами и не знают о нём.
- Системы не должны зависеть друг от друга напрямую — общаются через сигналы и данные. Одна сломанная сцена не должна ломать всю игру.
- Тексты, числа баланса, данные предметов — не в коде, а в отдельных ресурсах/файлах (формат решается на этапе 3).

## Асинхронность
- Ожидание — через `await` сигнала или таймера: `await get_tree().create_timer(0.5).timeout`.
- После `await` проверяй `is_inside_tree()` и `is_instance_valid()` **других** узлов, которые используешь дальше: за время ожидания сцена могла смениться. `is_instance_valid(self)` бесполезна — корутина удалённого узла просто не продолжается.

## Форматирование
- Отступ — табы. Строка — до 100 символов (лучше до 80).
- Между функциями — две пустые строки; внутри функции — одна пустая строка между логическими блоками. Больше одной пустой строки подряд внутри функции не ставим.
- Блоки `if` / `for` / `while` / `match` отделяем пустой строкой от соседнего кода.
- Пробелы вокруг операторов и после запятых. Строки — в двойных кавычках.
- Многострочные массивы, словари, enum — с запятой после последнего элемента.

## Комментарии
- Сначала понятный код, потом комментарий. Комментируй «почему», а не «что».
- Комментарий нужен: неочевидный приём, обход бага движка, строка, которую нельзя удалять.
- Документация класса и публичных функций — `##`. Пробел после `#`.
