class_name RuneGame
extends Node2D
## Мини-игра «амулет ведьмы» (песочница, #60): руны загораются по очереди — повтори их кликами.
## С каждым кругом порядок длиннее. Ошибка — амулет трескается, тот же порядок покажут снова.
## Вариант — в `common/items.json`: runes, length, shuffle (руны меняются местами между кругами),
## reversed (повторять с конца), same_color (все руны одного цвета), show_time, price_bonus.

signal finished(stars: int)
signal mistake_made

const STARS_MAX := 3
const RING_POINTS := 48
const RUNE_RADIUS := 62.0
const GLYPH_SCALE := 34.0
const LIT_GROW := 1.2
## Значки рун: ломаные в клетке от -1 до 1.
const GLYPHS: Array = [
	[Vector2(0, -1), Vector2(0, 1), Vector2(0, -0.2), Vector2(0.7, -0.9)],
	[Vector2(-0.7, 1), Vector2(0, -1), Vector2(0.7, 1), Vector2(-0.5, 0.2), Vector2(0.5, 0.2)],
	[Vector2(-0.7, -1), Vector2(0.7, 0), Vector2(-0.7, 1)],
	[Vector2(-0.7, 1), Vector2(-0.7, -1), Vector2(0.7, 1), Vector2(0.7, -1)],
	[Vector2(0, -1), Vector2(0.8, 0), Vector2(0, 1), Vector2(-0.8, 0), Vector2(0, -1)],
	[Vector2(-0.8, -0.8), Vector2(0.8, 0.8), Vector2(0, 0), Vector2(0.8, -0.8), Vector2(-0.8, 0.8)],
	[Vector2(-0.7, 1), Vector2(-0.7, -1), Vector2(0.6, -0.4), Vector2(-0.7, 0.2)],
	[Vector2(-0.8, -1), Vector2(0, 0), Vector2(0.8, -1), Vector2(0, 0), Vector2(0, 1)],
]
const COLORS: Array[Color] = [
	Color(0.95, 0.35, 0.3),
	Color(0.35, 0.65, 1.0),
	Color(0.45, 0.9, 0.4),
	Color(0.95, 0.8, 0.25),
	Color(0.8, 0.45, 0.95),
	Color(0.3, 0.9, 0.85),
	Color(1.0, 0.55, 0.2),
	Color(0.95, 0.55, 0.75),
]

@export var center: Vector2 = Vector2(960, 590)
@export var circle_radius: float = 290.0
## Пауза перед показом и между рунами, с.
@export var pause_before_show: float = 0.7
@export var pause_between_runes: float = 0.2
@export var click_flash_time: float = 0.2
@export var finish_pause: float = 0.6

@export_group("Вид")
@export var amulet_color: Color = Color(0.72, 0.56, 0.24)
@export var gem_color: Color = Color(0.45, 0.2, 0.65)
@export var crack_color: Color = Color(0.06, 0.03, 0.03)
@export var stone_color: Color = Color(0.13, 0.11, 0.17, 0.95)
@export var dim_rune_share: float = 0.45
@export var same_color: Color = Color(0.8, 0.45, 0.95)

var _is_running: bool = false
var _is_showing: bool = false
var _rune_count: int = 6
var _length: int = 5
var _shuffles: bool = false
var _is_reversed: bool = false
var _uses_same_color: bool = false
var _show_time: float = 0.55
var _price_bonus: int = 0
## Весь порядок рун; на круге видна его начальная часть.
var _sequence: Array[int] = []
var _round_length: int = 1
var _input_index: int = 0
var _mistake_count: int = 0
## Какая руна на каком месте круга.
var _places: Array[int] = []
var _lit_rune: int = -1
## Трещины амулета: отрезки.
var _cracks: Array[PackedVector2Array] = []


func _ready() -> void:
	hide()


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if not _is_running or mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	get_viewport().set_input_as_handled()
	if mouse_event.pressed and not _is_showing:
		_click(get_global_mouse_position())


func _draw() -> void:
	draw_circle(center, circle_radius + RUNE_RADIUS + 24.0, stone_color)
	draw_arc(center, circle_radius, 0.0, TAU, RING_POINTS, amulet_color, 8.0, true)
	draw_circle(center, 120.0, amulet_color)
	draw_circle(center, 74.0, gem_color)
	for crack in _cracks:
		draw_polyline(crack, crack_color, 5.0, true)

	for place in _places.size():
		_draw_rune(place)


## Начать по варианту из `items.json`.
func start(variant: Dictionary) -> void:
	_rune_count = mini(int(variant.get("runes", 6)), GLYPHS.size())
	_length = int(variant.get("length", 5))
	_shuffles = variant.get("shuffle", false)
	_is_reversed = variant.get("reversed", false)
	_uses_same_color = variant.get("same_color", false)
	_show_time = variant.get("show_time", _show_time)
	_price_bonus = int(variant.get("price_bonus", 0))
	_sequence.clear()
	for _step in _length:
		_sequence.append(randi_range(0, _rune_count - 1))

	_places.clear()
	for rune in _rune_count:
		_places.append(rune)

	_round_length = 1
	_mistake_count = 0
	_cracks.clear()
	show()
	_is_running = true
	_play_round()


func get_price_bonus() -> int:
	return _price_bonus


## Сколько кругов пройдено: доля от 0 до 1.
func get_progress_ratio() -> float:
	return float(_round_length - 1) / maxf(_length, 1.0)


## Шкалы натяжения в этой игре нет.
func get_tension() -> float:
	return 0.0


## Сколько звёзд выйдет, если закончить сейчас.
func get_stars() -> int:
	return clampi(STARS_MAX - _mistake_count, 1, STARS_MAX)


func _play_round() -> void:
	_is_showing = true
	_input_index = 0
	await get_tree().create_timer(pause_before_show).timeout
	for step in _round_length:
		_lit_rune = _sequence[step]
		await get_tree().create_timer(_show_time).timeout
		_lit_rune = -1
		await get_tree().create_timer(pause_between_runes).timeout

	if _shuffles:
		_places.shuffle()

	_is_showing = false


## Какую руну ждём сейчас: с начала круга или с конца.
func _get_expected_rune() -> int:
	var step := _input_index
	if _is_reversed:
		step = _round_length - 1 - _input_index

	return _sequence[step]


func _click(point: Vector2) -> void:
	for place in _places.size():
		if point.distance_to(_get_place_position(place)) <= RUNE_RADIUS:
			_press_rune(_places[place])
			break


func _press_rune(rune: int) -> void:
	_flash_rune(rune)
	if rune != _get_expected_rune():
		_mistake_count += 1
		_add_crack()
		mistake_made.emit()
		_play_round()
		return

	_input_index += 1
	if _input_index < _round_length:
		return

	_round_length += 1
	if _round_length > _length:
		_finish()
	else:
		_play_round()


func _flash_rune(rune: int) -> void:
	_lit_rune = rune
	await get_tree().create_timer(click_flash_time).timeout
	if not _is_showing:
		_lit_rune = -1


func _finish() -> void:
	_is_running = false
	await get_tree().create_timer(finish_pause).timeout
	finished.emit(get_stars())


func _add_crack() -> void:
	var angle := randf_range(0.0, TAU)
	var crack := PackedVector2Array([center + Vector2.from_angle(angle) * 118.0])
	crack.append(center + Vector2.from_angle(angle + 0.3) * 70.0)
	crack.append(center + Vector2.from_angle(angle - 0.2) * 20.0)
	_cracks.append(crack)


func _get_place_position(place: int) -> Vector2:
	var angle := TAU * place / _places.size() - PI / 2.0
	return center + Vector2.from_angle(angle) * circle_radius


func _get_rune_color(rune: int) -> Color:
	return same_color if _uses_same_color else COLORS[rune]


func _draw_rune(place: int) -> void:
	var rune := _places[place]
	var position_on_circle := _get_place_position(place)
	var is_lit := rune == _lit_rune
	var color := _get_rune_color(rune)
	var shown_color := color if is_lit else color * Color(1.0, 1.0, 1.0, dim_rune_share)
	var radius := RUNE_RADIUS * (LIT_GROW if is_lit else 1.0)
	draw_circle(position_on_circle, radius, stone_color)
	if is_lit:
		draw_circle(position_on_circle, radius, Color(color, 0.35))

	draw_arc(position_on_circle, radius, 0.0, TAU, RING_POINTS, shown_color, 5.0, true)
	var points := PackedVector2Array()
	for point: Vector2 in GLYPHS[rune]:
		points.append(position_on_circle + point * GLYPH_SCALE)

	draw_polyline(points, shown_color, 7.0, true)
