class_name ScalesGame
extends Node2D
## Мини-игра «весы торговца» (песочница, #60): на левой чаше мерка неизвестного веса.
## Клик по гирьке ставит её на правую чашу или снимает. По наклону коромысла подбери вес:
## держится ровно — мерка сошлась, приносят следующую. Лишние ходы снимают звёзды.
## Вариант — в `common/items.json`: weights, rounds, par_moves, shows_amount, price_bonus.

signal finished(stars: int)
signal mistake_made

const STARS_MAX := 3
const MAX_TILT := 0.32
## Без подсказки о величине коромысло всегда наклоняется на столько.
const FIXED_TILT := 0.2
const TILT_PER_UNIT := 0.03
const WEIGHT_BASE_SIZE := Vector2(58, 50)
const WEIGHT_SIZE_STEP := 7.0
const WEIGHT_GAP := 18.0
const PAN_HALF_WIDTH := 110.0
const PAN_DROP := 160.0
const POST_WIDTH := 22.0
const FONT_SIZE := 28

@export var pivot: Vector2 = Vector2(960, 300)
@export var beam_half_length: float = 330.0
@export var tray_center: Vector2 = Vector2(960, 830)
## Как быстро коромысло догоняет нужный наклон.
@export var tilt_speed: float = 6.0
## Сколько секунд весы должны стоять ровно, чтобы мерка сошлась.
@export var balance_time: float = 0.9
@export var finish_pause: float = 0.5

@export_group("Качество")
## Сколько лишних ходов (доля от нормы) ещё дают 3 и 2 звезды.
@export var three_stars_extra: float = 0.25
@export var two_stars_extra: float = 0.9

@export_group("Вид")
@export var wood_color: Color = Color(0.3, 0.17, 0.08)
@export var brass_color: Color = Color(0.82, 0.62, 0.25)
@export var dark_brass_color: Color = Color(0.45, 0.32, 0.12)
@export var mystery_color: Color = Color(0.3, 0.2, 0.42)
@export var weight_color: Color = Color(0.55, 0.57, 0.62)
@export var text_color: Color = Color(1.0, 0.95, 0.85)
@export var balanced_color: Color = Color(0.45, 0.9, 0.4)

var _is_running: bool = false
var _weights: Array[int] = []
var _on_pan: Array[bool] = []
var _target: int = 0
var _round_index: int = 0
var _round_count: int = 1
var _par_moves: int = 1
var _move_count: int = 0
var _shows_amount: bool = true
var _price_bonus: int = 0
var _tilt: float = 0.0
var _balanced_left: float = 0.0


func _ready() -> void:
	hide()


func _process(delta: float) -> void:
	_tilt = lerpf(_tilt, _get_wanted_tilt(), minf(tilt_speed * delta, 1.0))
	queue_redraw()
	if not _is_running:
		return

	if _get_pan_weight() != _target or _target == 0:
		_balanced_left = balance_time
		return

	_balanced_left -= delta
	if _balanced_left <= 0.0:
		_next_round()


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if not _is_running or mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	get_viewport().set_input_as_handled()
	if mouse_event.pressed:
		_click(get_global_mouse_position())


func _draw() -> void:
	var left := _get_beam_end(-1.0)
	var right := _get_beam_end(1.0)
	var base := Vector2(pivot.x, tray_center.y - 60.0)
	draw_line(pivot, base, wood_color, POST_WIDTH)
	draw_line(base + Vector2(-120, 0), base + Vector2(120, 0), wood_color, POST_WIDTH)
	draw_line(left, right, brass_color, 14.0)
	draw_circle(pivot, 20.0, _get_pivot_color())
	_draw_pan(left, true)
	_draw_pan(right, false)
	_draw_tray()


## Начать по варианту из `items.json`.
func start(variant: Dictionary) -> void:
	_weights.clear()
	_on_pan.clear()
	for weight: float in variant.get("weights", [1.0, 2.0, 4.0]):
		_weights.append(int(weight))
		_on_pan.append(false)

	_round_count = int(variant.get("rounds", 2))
	_par_moves = int(variant.get("par_moves", 6))
	_shows_amount = variant.get("shows_amount", true)
	_price_bonus = int(variant.get("price_bonus", 0))
	_round_index = 0
	_move_count = 0
	_pick_target()
	show()
	_is_running = true


func get_price_bonus() -> int:
	return _price_bonus


## Сколько мерок сошлось: доля от 0 до 1.
func get_progress_ratio() -> float:
	return float(_round_index) / maxf(_round_count, 1.0)


## Сколько ходов потрачено: 1 — вся норма на все мерки.
func get_tension() -> float:
	return clampf(float(_move_count) / maxf(_par_moves * _round_count, 1.0), 0.0, 1.0)


## Сколько звёзд выйдет, если закончить сейчас.
func get_stars() -> int:
	var par_total := maxf(_par_moves * _round_count, 1.0)
	var extra := (_move_count - par_total) / par_total
	var stars := 1
	if extra <= three_stars_extra:
		stars = STARS_MAX
	elif extra <= two_stars_extra:
		stars = 2

	return stars


## Загадать вес, который точно набирается гирьками: сумма случайных из них, не меньше двух.
func _pick_target() -> void:
	var shuffled := _weights.duplicate()
	shuffled.shuffle()
	var count := randi_range(mini(2, shuffled.size()), shuffled.size())
	var total := 0
	for weight_index in count:
		total += shuffled[weight_index]

	_target = total
	_balanced_left = balance_time
	_on_pan.fill(false)


func _next_round() -> void:
	_round_index += 1
	if _round_index >= _round_count:
		_is_running = false
		await get_tree().create_timer(finish_pause).timeout
		finished.emit(get_stars())
	else:
		_pick_target()


func _get_pan_weight() -> int:
	var total := 0
	for weight_index in _weights.size():
		if _on_pan[weight_index]:
			total += _weights[weight_index]

	return total


## Положительный наклон — правая чаша ниже.
func _get_wanted_tilt() -> float:
	var difference := _get_pan_weight() - _target
	var wanted := 0.0
	if _shows_amount:
		wanted = clampf(difference * TILT_PER_UNIT, -MAX_TILT, MAX_TILT)
	elif difference != 0:
		wanted = FIXED_TILT * signi(difference)

	return wanted


func _get_beam_end(side: float) -> Vector2:
	return pivot + Vector2(side * beam_half_length, 0.0).rotated(_tilt)


func _get_pivot_color() -> Color:
	var is_balanced := _is_running and _get_pan_weight() == _target
	return balanced_color if is_balanced else dark_brass_color


func _click(point: Vector2) -> void:
	for weight_index in _weights.size():
		if _get_weight_rect(weight_index).has_point(point):
			_on_pan[weight_index] = not _on_pan[weight_index]
			_move_count += 1
			if _move_count > _par_moves * _round_count:
				mistake_made.emit()
			break


func _get_weight_size(weight_index: int) -> Vector2:
	return WEIGHT_BASE_SIZE + Vector2.ONE * WEIGHT_SIZE_STEP * weight_index


## Где гирька сейчас: на подносе или на правой чаше.
func _get_weight_rect(weight_index: int) -> Rect2:
	var size := _get_weight_size(weight_index)
	if _on_pan[weight_index]:
		var pan_center := _get_beam_end(1.0) + Vector2(0.0, PAN_DROP)
		var pan_count := _on_pan.count(true)
		var place := 0
		for other_index in weight_index:
			if _on_pan[other_index]:
				place += 1

		var step := PAN_HALF_WIDTH * 2.0 / pan_count
		var x := pan_center.x - PAN_HALF_WIDTH + step * (place + 0.5)
		return Rect2(Vector2(x - size.x / 2.0, pan_center.y - size.y), size)

	var total_width := 0.0
	for other_index in _weights.size():
		total_width += _get_weight_size(other_index).x + WEIGHT_GAP

	var left := tray_center.x - total_width / 2.0
	for other_index in weight_index:
		left += _get_weight_size(other_index).x + WEIGHT_GAP

	return Rect2(Vector2(left, tray_center.y - size.y), size)


func _draw_pan(beam_end: Vector2, is_mystery: bool) -> void:
	var center := beam_end + Vector2(0.0, PAN_DROP)
	var offset := Vector2(PAN_HALF_WIDTH, 0.0)
	draw_line(beam_end, center - offset, dark_brass_color, 4.0)
	draw_line(beam_end, center + offset, dark_brass_color, 4.0)
	draw_line(center - offset, center + offset, brass_color, 12.0)
	if is_mystery:
		var box := Rect2(center + Vector2(-46.0, -86.0), Vector2(92.0, 80.0))
		draw_rect(box, mystery_color)
		_draw_centered_text(box, "?")


func _draw_tray() -> void:
	var tray_rect := Rect2(tray_center + Vector2(-420.0, 0.0), Vector2(840.0, 22.0))
	draw_rect(tray_rect, wood_color)
	for weight_index in _weights.size():
		var rect := _get_weight_rect(weight_index)
		draw_rect(rect, weight_color)
		draw_rect(rect, dark_brass_color, false, 3.0)
		_draw_centered_text(rect, str(_weights[weight_index]))


func _draw_centered_text(rect: Rect2, text: String) -> void:
	var at := Vector2(rect.position.x, rect.get_center().y + FONT_SIZE * 0.35)
	var font := ThemeDB.fallback_font
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, FONT_SIZE, text_color)
