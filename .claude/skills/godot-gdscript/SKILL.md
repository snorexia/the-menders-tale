---
name: godot-gdscript
description: Пишешь или правишь GDScript (Godot 4.7) — типизация, := и Variant, Array[T]/Dictionary[K,V], @export/@onready, сигналы и Callable, await и корутины, call_deferred, ловушки и предупреждения. GDScript typing, signals, await, warnings.
---

# GDScript в Godot 4.7

Ловушки языка: типы, аннотации, сигналы, корутины, предупреждения. **Стиль** (имена, порядок в файле, `not`, табы) — в `.claude/rules/gdscript-style.md`, он главнее примеров отсюда. Сцены и связи между узлами — скилл `godot-scenes`, интерфейс — `godot-ui`. Источники — `.claude/skills/THIRD_PARTY.md`.

Перед завершением: `gdlint <файл или папка>` (конфиг `gdlintrc` в корне).

## Сначала встроенное
| Нужно | Используй | Не пиши сам |
|---|---|---|
| Подождать один раз | `await get_tree().create_timer(t).timeout` или узел `Timer` | счётчик `delta` в `_process` |
| Периодически | сигнал `timeout` у `Timer` | `if elapsed > 0.5` в `_process` |
| Плавно к цели | `move_toward()`, `lerpf()`, `Tween` | свою интерполяцию |
| Найти узел | `%Имя`, `@export var x: Node`, `@onready` | длинный путь `get_node("../../A/B")` |
| Имя ↔ значение enum | `State.keys()`, `State.find_key(v)` | таблицу строк в `match` |
| Обработать массив | `filter`, `map`, `reduce`, `any`, `all`, `sort_custom`, `pick_random` | цикл с временным массивом |
| Сравнить float | `is_equal_approx()`, `is_zero_approx()` | `==` |
| Вызвать в конце кадра | `callable.call_deferred()`, `set_deferred()` | таймер на один кадр |
| Данные, правимые в инспекторе | наследник `Resource` с `@export` | ручной разбор JSON |

## Типизация
```gdscript
var speed: float = 200.0
var names: Array[String] = []
var scores: Dictionary[StringName, int] = {}


func _ready() -> void:
	var raw: Dictionary = {"k": 1}
	var value: int = raw["k"]
	var sprite := get_node_or_null("Sprite") as Sprite2D
```
- `:=` выводит тип из правой части. Если там `Variant` — ошибка `inference_on_variant`. `Variant` возвращают: доступ к нетипизированному `Dictionary`, `call()`, а также глобальные `clamp`, `min`, `max`, `lerp`, `abs`, `sign`, `floor`, `ceil`, `round`, `snapped`. Бери типизированные `clampf`/`clampi`, `minf`/`mini`, `maxf`/`maxi`, `lerpf`, `absf`/`absi`, `floorf`/`floori`, `roundf`/`roundi`, `snappedf` — или пиши тип явно.
- `load()` возвращает `Resource`: `var tex: Texture2D = load(path)`. Путь-константа → `preload()`, он даёт точный тип.
- `$Node` и `get_node()` возвращают `Node`: `@onready var sprite: Sprite2D = $Sprite` — несовпадение типа всплывёт сразу при загрузке. `as` при неудаче молча даёт `null`; сначала `is`, потом `as`.
- `Array[T]` проверяет типы элементов при работе. `map()` возвращает нетипизированный `Array` — присваивай через `typed.assign(untyped)`. `filter()` тип сохраняет.
- `Dictionary[K, V]` — с 4.4; вложенные типы не поддерживаются (`Dictionary[String, Dictionary]` можно).
- Тип переменной цикла: `for node: Node in nodes:`.
- Много чисел — `PackedFloat32Array`, `PackedVector2Array`; `Array[float]` всё равно массив `Variant`.
- Enum как тип — это `int`; передача числа вызывает `int_as_enum_without_cast` — передавай член enum.
- **4.7:** переопределённый метод наследует тип возврата родителя — переопределение без `return` теперь ошибка. `type_exists()` устарел → `ClassDB.class_exists()`.

## class_name и preload
- `class_name Foo` регистрирует глобальный класс. Не может совпадать с именем autoload (`hides an autoload singleton`) и классом движка.
- Скрипт без `class_name` — через константу: `const Rifle := preload("res://.../rifle.gd")`. Путь известен только при запуске → `load()`.
- `@export` принимает встроенные типы, `Resource`, `Node`, enum. Внутренний класс-наследник `RefCounted` — ошибка разбора.
- Синтаксиса Godot 3 нет: `export var`, `onready var`, `yield`, `connect("sig", obj, "method")`.

## Аннотации
```gdscript
@export var speed: float = 200.0
@export_range(0.0, 1.0, 0.01) var ratio: float = 0.5
@export_file("*.tscn") var next_scene: String
@export var spawn_point: Marker2D

@export_group("Loot")
@export var drops: Array[Resource] = []

@onready var _label: Label = %Label
```
- Порядок: значения из объявления → `_init()` → значения, сохранённые в сцене → `_ready()`. В `_init()` видны только значения по умолчанию.
- Сеттер экспортируемой переменной вызывается при создании сцены **до** `_ready()` — `@onready` ещё `null`; проверяй `is_node_ready()`.
- `@onready` вместе с `@export` — ошибка. `$` в значении по умолчанию без `@onready` — ошибка.
- Значение, уже сохранённое в сцене, перекрывает новое значение по умолчанию в скрипте.
- `@export var n: Node` — только в скриптах-наследниках `Node`, не в `Resource`.
- Группа `@export_group` действует до следующей; закрыть — `@export_group("")`.
- С 4.5 `@export_file` хранит UID; нужен путь — `@export_file_path`.

## Сигналы
```gdscript
signal damaged(amount: int, source: Node)

@export var _button: Button


func _ready() -> void:
	_button.pressed.connect(_on_button_pressed)
	damaged.connect(_log_damage.bind("player"))
```
- Аргументы `bind()` добавляются **после** аргументов сигнала; `unbind(n)` отбрасывает n последних.
- Повторный `connect` того же Callable — ошибка `ERR_INVALID_PARAMETER`; проверяй `is_connected()`.
- `CONNECT_ONE_SHOT` — сработает один раз; `CONNECT_DEFERRED` — в конце кадра.
- Ссылка на метод (`_on_button_pressed`), а не строка (`Callable(self, "...")`, `call("do_it")`): опечатку в строке увидишь только при запуске.
- Лямбда захватывает локальные переменные **по значению один раз**: `count += 1` внутри не меняет внешнюю. Общее состояние — в член класса, `Array` или `Dictionary`.
- Сигнал, который вызывают снаружи класса, даёт `unused_signal` → `@warning_ignore("unused_signal")`.

## await и корутины
```gdscript
func open_door(door: Node3D) -> void:
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree() or not is_instance_valid(door):
		return

	door.hide()
```
- Функция с `await` — корутина. Если вызывающий не пишет `await`, он продолжает работу сразу после первого `await` внутри.
- После `await` мир изменился: **другие** узлы могли удалиться, сам узел — выйти из дерева (`get_tree()` тогда `null`). Проверяй `is_inside_tree()` и `is_instance_valid(другой_узел)`.
- Если удалён **сам** узел, его корутина просто не продолжается — проверка `is_instance_valid(self)` бесполезна. Очистку, которая должна выполниться, ставь в `_exit_tree()`.
- `create_timer(t)` по умолчанию идёт и на паузе; чтобы останавливался — `create_timer(t, false)`.
- `await get_tree().process_frame` — ждать кадр; `await node.ready` — готовность узла. Встроенного таймаута нет — гонка сигнала с `Timer`.

## Жизнь объектов
- Переменная с удалённым (`free()`) объектом не становится `null` — ошибка `previously freed`. Проверка — `is_instance_valid()`.
- После `queue_free()` до конца кадра `is_instance_valid()` ещё `true`; «уже удаляется» — `is_queued_for_deletion()`.
- В обработчиках физики, сигналов и при обходе детей удаляй через `queue_free()`, не `free()`.
- `RefCounted` и `Resource` удаляются сами по счётчику ссылок — `free()` не нужен.
- В `_init()` узла ещё нет в дереве — `get_node()` не сработает; такую логику — в `_ready()`.

## Отладка
- `assert(cond, "msg")` работает только в отладочной сборке; без побочных эффектов в условии.
- Ошибки — `push_error()` / `push_warning()` (со стеком, в панель отладчика), а не `print()`.
- Отладочный вывод — внутри `if OS.is_debug_build():`.

## Ловушки
- `5 / 2` = `2` (целочисленное, `integer_division`) → `5 / 2.0` или `float(a) / b`.
- `Array` и `Dictionary` передаются по ссылке; копия — `duplicate()`, вложенная — `duplicate(true)`.
- `const`-массив только для чтения.
- Наследник с `_init()` или `_ready()` не вызывает родительский сам — `super()`.
- Значение из объявления не вызывает сеттер; присваивание в других методах — вызывает.
- Неиспользуемый параметр — с `_` (`_delta`).
- Удалять или добавлять элементы во время обхода массива — пропуски; обходи копию.
- `randomize()` при старте уже вызван; фиксированный сид — `seed()`.
- Метод с именем как у метода движка — ошибка `native_method_override`. Локальная переменная с именем члена — `shadowed_variable`.
- В физических обратных вызовах менять коллизии — через `set_deferred()`, иначе `Can't change this state while flushing queries`.

## Предупреждения проекта
`project.godot`, раздел `[debug]` (0 — игнор, 1 — предупреждение, 2 — ошибка). Для полностью типизированного кода по нашему правилу:
```ini
gdscript/warnings/untyped_declaration=2
gdscript/warnings/missing_await=1
gdscript/warnings/narrowing_conversion=2
gdscript/warnings/int_as_enum_without_cast=2
```
`inferred_declaration` держи 0 — мы используем `:=`, где тип очевиден.

## Документация
- [Основы GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html) · [Статическая типизация](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html) · [Переход на 4.7](https://docs.godotengine.org/en/latest/tutorials/migrating/upgrading_to_godot_4.7.html)
