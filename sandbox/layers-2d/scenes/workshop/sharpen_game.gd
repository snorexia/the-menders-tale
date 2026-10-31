class_name SharpenGame
extends Node2D
## Мини-игра «заточи косу» (песочница, #60): зажми кнопку и води точилом вдоль лезвия.
## Там, где прошёл, зазубрины исчезают. Слишком быстро — лезвие перегревается и снова тупится.
## Вариант — в `common/items.json`: edge (линия лезвия), smooth, width, passes, max_speed,
## price_bonus.

signal finished(stars: int)
signal mistake_made

const STARS_MAX := 3
const SAMPLE_STEP := 12.0
const NICK_HEIGHT := 11.0
const HANDLE_LENGTH := 260.0
const HANDLE_WIDTH := 34.0
const STONE_SIZE := Vector2(110, 40)
const DONE_WEAR := 0.04

## На каком расстоянии от лезвия точило работает, px.
@export var reach: float = 46.0
## На сколько затупляется участок при перегреве и какой он ширины, px.
@export var overheat_wear: float = 0.6
@export var overheat_radius: float = 90.0
## Как быстро растёт и спадает нагрев: доля шкалы в секунду.
@export var heat_rise: float = 1.4
@export var heat_fall: float = 0.7
@export var finish_pause: float = 0.5

@export_group("Качество")
@export var mistake_penalty: float = 0.15
@export var three_stars_from: float = 0.85
@export var two_stars_from: float = 0.6

@export_group("Вид")
@export var board_color: Color = Color(0.1, 0.07, 0.05, 0.5)
@export var steel_color: Color = Color(0.48, 0.5, 0.54)
@export var dull_color: Color = Color(0.2, 0.17, 0.15)
@export var sharp_color: Color = Color(0.95, 0.97, 1.0)
@export var hot_color: Color = Color(1.0, 0.4, 0.15)
@export var handle_color: Color = Color(0.42, 0.25, 0.12)
@export var stone_color: Color = Color(0.36, 0.38, 0.36)

var _is_running: bool = false
var _is_holding: bool = false
var _points: PackedVector2Array = PackedVector2Array()
var _normals: PackedVector2Array = PackedVector2Array()
## Насколько тупой участок: 1 — весь в зазубринах, 0 — острый.
var _wear: PackedFloat32Array = PackedFloat32Array()
var _blade: PackedVector2Array = PackedVector2Array()
var _passes: float = 300.0
var _max_speed: float = 900.0
var _heat: float = 0.0
var _mistake_count: int = 0
var _price_bonus: int = 0
var _last_mouse: Vector2 = Vector2.ZERO


func _ready() -> void:
	hide()


func _process(delta: float) -> void:
	queue_redraw()
	if not _is_running:
		return

	var mouse := get_global_mouse_position()
	var moved := mouse.distance_to(_last_mouse)
	_last_mouse = mouse
	if _is_holding and moved / maxf(delta, 0.001) > _max_speed:
		_heat = minf(_heat + heat_rise * delta, 1.0)
	else:
		_heat = maxf(_heat - heat_fall * delta, 0.0)

	if _heat >= 1.0:
		_overheat(mouse)
	elif _is_holding:
		_grind(mouse, moved)


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if not _is_running or mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	get_viewport().set_input_as_handled()
	_is_holding = mouse_event.pressed
	_last_mouse = get_global_mouse_position()


func _draw() -> void:
	if _points.size() < 2:
		return

	var first_direction := (_points[0] - _points[1]).normalized()
	var handle_end := _points[0] + first_direction * HANDLE_LENGTH
	draw_line(_points[0], handle_end, handle_color, HANDLE_WIDTH)
	draw_colored_polygon(_blade, steel_color.lerp(hot_color, _heat * 0.6))
	for index in range(1, _points.size()):
		_draw_edge_piece(index)

	if _is_holding and _is_running:
		var stone := Rect2(get_global_mouse_position() - STONE_SIZE / 2.0, STONE_SIZE)
		draw_rect(stone, stone_color)


## Начать по варианту из `items.json`.
func start(variant: Dictionary) -> void:
	var raw := PackedVector2Array()
	for point: Array in variant.get("edge", []):
		raw.append(Vector2(point[0], point[1]))

	if variant.get("smooth", false):
		raw = StitchSeam.smooth_path(raw)

	_passes = variant.get("passes", _passes)
	_max_speed = variant.get("max_speed", _max_speed)
	_price_bonus = int(variant.get("price_bonus", 0))
	_build_blade(raw, variant.get("width", 80.0))
	_mistake_count = 0
	_heat = 0.0
	_is_holding = false
	show()
	_is_running = true


func get_price_bonus() -> int:
	return _price_bonus


## Сколько лезвия заточено: доля от 0 до 1.
func get_progress_ratio() -> float:
	var total := 0.0
	for wear in _wear:
		total += wear

	return 1.0 - total / maxf(_wear.size(), 1.0)


## Нагрев лезвия: доля от 0 до 1.
func get_tension() -> float:
	return _heat


## Сколько звёзд выйдет, если закончить сейчас.
func get_stars() -> int:
	var accuracy := 1.0 - mistake_penalty * _mistake_count
	var stars := 1
	if accuracy >= three_stars_from:
		stars = STARS_MAX
	elif accuracy >= two_stars_from:
		stars = 2

	return stars


## Разбить лезвие на участки, посчитать обух: от рукояти к острию лезвие сужается.
func _build_blade(raw: PackedVector2Array, width: float) -> void:
	_points.clear()
	_normals.clear()
	_wear.clear()
	for segment in range(1, raw.size()):
		var from := raw[segment - 1]
		var to := raw[segment]
		var count := maxi(int(from.distance_to(to) / SAMPLE_STEP), 1)
		for step in count:
			_points.append(from.lerp(to, float(step) / count))

	_points.append(raw[-1])
	var back := PackedVector2Array()
	for index in _points.size():
		var before := _points[maxi(index - 1, 0)]
		var after := _points[mini(index + 1, _points.size() - 1)]
		var normal := (after - before).normalized().orthogonal()
		_normals.append(normal)
		_wear.append(1.0)
		var share := float(index) / (_points.size() - 1)
		back.append(_points[index] + normal * width * sqrt(1.0 - share))

	back.reverse()
	_blade = _points.duplicate()
	_blade.append_array(back)


func _grind(mouse: Vector2, moved: float) -> void:
	var is_done := true
	for index in _points.size():
		if mouse.distance_to(_points[index]) <= reach:
			_wear[index] = maxf(_wear[index] - moved / _passes, 0.0)

		if _wear[index] > DONE_WEAR:
			is_done = false

	if is_done:
		_finish()


func _overheat(mouse: Vector2) -> void:
	_heat = 0.0
	_is_holding = false
	_mistake_count += 1
	for index in _points.size():
		if mouse.distance_to(_points[index]) <= overheat_radius:
			_wear[index] = minf(_wear[index] + overheat_wear, 1.0)

	mistake_made.emit()


func _finish() -> void:
	_is_running = false
	_is_holding = false
	await get_tree().create_timer(finish_pause).timeout
	finished.emit(get_stars())


func _draw_edge_piece(index: int) -> void:
	var from := _points[index - 1]
	var to := _points[index]
	var wear := _wear[index]
	var color := sharp_color.lerp(dull_color, wear)
	# Зазубрины: чередуем сдвиг наружу, чем тупее, тем сильнее.
	var side := 1.0 if index % 2 == 0 else -1.0
	var bump := -_normals[index] * NICK_HEIGHT * wear * (0.5 + 0.5 * side)
	draw_line(from, to + bump, color, 6.0, true)
