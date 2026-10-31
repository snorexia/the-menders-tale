class_name BoxGame
extends Node2D
## Мини-игра «почини шкатулку» (песочница, #60), четыре шага:
## вытащи гвозди клещами (тяни вверх, не рви) → сними сломанную часть → выбери подходящую по
## форме новую и поставь на место → забей гвозди (зажми, отпусти, когда сила в зелёной зоне).
## Вариант — в `common/items.json`: part (прямоугольник части от центра крышки), part_color,
## nails (точки от центра), notch (вырез настоящей части: доля длины), price_bonus.

signal finished(stars: int)
signal mistake_made

enum Step { PULL, REMOVE, PLACE, DRIVE, DONE }

const STARS_MAX := 3
const NAIL_RADIUS := 11.0
const NAIL_WIDTH := 7.0
## Сколько части гвоздя торчит: 0 — забит, 1 — вытащен.
const NAIL_DRIVEN := 0.0
const NAIL_STANDING := 0.7
const NOTCH_WIDTH := 70.0
const NOTCH_DEPTH := 30.0
const OPTION_SHARES: Array[float] = [0.2, 0.5, 0.8]
const CHARGE_BAR_SIZE := Vector2(260, 26)
const OPTION_GAP := 30.0

@export var lid_center: Vector2 = Vector2(960, 480)
@export var lid_size: Vector2 = Vector2(900, 560)
## Куда тянуть гвоздь и на сколько, px.
@export var pull_distance: float = 110.0
## Быстрее этого гвоздь гнётся и срывается, px в секунду.
@export var pull_max_speed: float = 900.0
## Как плавно считается скорость руки: один рывок мыши гвоздь не гнёт.
@export var speed_smoothing: float = 10.0
## Как далеко унести сломанную часть, px.
@export var remove_distance: float = 170.0
@export var snap_distance: float = 80.0
## Сила удара: сколько секунд нарастает от 0 до 1, потом идёт обратно.
@export var charge_time: float = 0.75
@export var charge_green_from: float = 0.62
@export var charge_green_to: float = 0.88
## Слабый удар вбивает гвоздь на эту долю.
@export var weak_hit_share: float = 0.4
@export var finish_pause: float = 0.6
@export var options_y: float = 880.0

@export_group("Качество")
@export var mistake_penalty: float = 0.13
@export var three_stars_from: float = 0.85
@export var two_stars_from: float = 0.6

@export_group("Тексты")
@export var pull_hint: String = "Зажми гвоздь и плавно тяни вверх"
@export var remove_hint: String = "Вытащи сломанную часть со шкатулки"
@export var place_hint: String = "Какая часть подходит по вырезу? Поставь её на место"
@export var drive_hint: String = "Зажми гвоздь и отпусти, когда сила в зелёной зоне"

@export_group("Вид")
@export var lid_color: Color = Color(0.42, 0.25, 0.12)
@export var lid_edge_color: Color = Color(0.2, 0.11, 0.05)
@export var plank_line_color: Color = Color(0.27, 0.15, 0.07)
@export var corner_color: Color = Color(0.75, 0.58, 0.25)
@export var hole_color: Color = Color(0.06, 0.04, 0.03)
@export var crack_color: Color = Color(0.05, 0.03, 0.02)
@export var nail_color: Color = Color(0.72, 0.72, 0.76)
@export var bent_color: Color = Color(0.85, 0.35, 0.25)
@export var pincers_color: Color = Color(0.25, 0.25, 0.28)
@export var charge_back_color: Color = Color(0.2, 0.15, 0.12)
@export var charge_green_color: Color = Color(0.4, 0.8, 0.35)
@export var charge_color: Color = Color(1.0, 0.95, 0.8)

var _is_running: bool = false
var _step: Step = Step.PULL
var _part: Rect2 = Rect2()
var _part_color: Color = Color.WHITE
var _nails: PackedVector2Array = PackedVector2Array()
## Сколько торчит каждый гвоздь: 0 — забит, 1 — вытащен.
var _heights: PackedFloat32Array = PackedFloat32Array()
var _notch_share: float = 0.5
var _options: Array[Dictionary] = []
var _active_nail: int = -1
var _pull_start_y: float = 0.0
var _pull_speed: float = 0.0
var _last_mouse: Vector2 = Vector2.ZERO
var _charge_time_passed: float = 0.0
var _part_offset: Vector2 = Vector2.ZERO
var _is_part_removed: bool = false
var _is_part_held: bool = false
var _held_option: int = -1
var _is_new_part_set: bool = false
var _mistake_count: int = 0
var _price_bonus: int = 0
var _total_steps: int = 1


func _ready() -> void:
	hide()


func _process(delta: float) -> void:
	queue_redraw()
	if not _is_running:
		return

	var mouse := get_global_mouse_position()
	match _step:
		Step.PULL:
			_process_pull(mouse, delta)
		Step.REMOVE:
			_process_remove(mouse)
		Step.PLACE:
			if _held_option != -1:
				_options[_held_option]["position"] = mouse
		Step.DRIVE:
			if _active_nail != -1:
				_charge_time_passed += delta

	_last_mouse = mouse


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if not _is_running or mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	get_viewport().set_input_as_handled()
	if mouse_event.pressed:
		_press(get_global_mouse_position())
	else:
		_release()


func _draw() -> void:
	if _part.size == Vector2.ZERO:
		return

	_draw_lid()
	_draw_part_slot()
	for nail_index in _nails.size():
		_draw_nail(nail_index)

	if _step == Step.PLACE:
		for option: Dictionary in _options:
			_draw_part_shape(option["position"], option["share"], _part_color)

	if _step == Step.DRIVE and _active_nail != -1:
		_draw_charge()


## Начать по варианту из `items.json`.
func start(variant: Dictionary) -> void:
	var raw_part: Array = variant.get("part", [-300, -60, 600, 120])
	_part = Rect2(raw_part[0], raw_part[1], raw_part[2], raw_part[3])
	_part.position += lid_center
	_part_color = Color(variant.get("part_color", "8a5a2b"))
	_nails.clear()
	_heights.clear()
	for point: Array in variant.get("nails", []):
		_nails.append(lid_center + Vector2(point[0], point[1]))
		_heights.append(NAIL_DRIVEN)

	_notch_share = variant.get("notch", OPTION_SHARES[1])
	_price_bonus = int(variant.get("price_bonus", 0))
	_build_options()
	_step = Step.PULL
	_total_steps = _nails.size() * 2 + 2
	_mistake_count = 0
	show()
	_is_running = true


func get_price_bonus() -> int:
	return _price_bonus


## Подсказка текущего шага: мастерская показывает её вместо подсказки рецепта.
func get_hint() -> String:
	var hint := drive_hint
	match _step:
		Step.PULL:
			hint = pull_hint
		Step.REMOVE:
			hint = remove_hint
		Step.PLACE:
			hint = place_hint

	return hint


## Сколько работы сделано: доля от 0 до 1.
func get_progress_ratio() -> float:
	var done := 0
	match _step:
		Step.PULL:
			for height in _heights:
				done += 1 if height >= 1.0 else 0
		Step.REMOVE:
			done = _nails.size()
		Step.PLACE:
			done = _nails.size() + 1
		Step.DRIVE:
			done = _nails.size() + 2
			for height in _heights:
				done += 1 if height <= NAIL_DRIVEN else 0
		Step.DONE:
			done = _total_steps

	return float(done) / _total_steps


## Шкалы натяжения в этой игре нет.
func get_tension() -> float:
	return 0.0


## Сколько звёзд выйдет, если закончить сейчас.
func get_stars() -> int:
	var accuracy := 1.0 - mistake_penalty * _mistake_count
	var stars := 1
	if accuracy >= three_stars_from:
		stars = STARS_MAX
	elif accuracy >= two_stars_from:
		stars = 2

	return stars


func _build_options() -> void:
	_options.clear()
	var shares: Array[float] = OPTION_SHARES.duplicate()
	if not _notch_share in shares:
		shares[0] = _notch_share

	shares.shuffle()
	for option_index in shares.size():
		var step := _part.size.x + OPTION_GAP
		var home := Vector2(lid_center.x + (option_index - 1) * step, options_y)
		var part_at := home - _part.size / 2.0
		_options.append({"share": shares[option_index], "home": part_at, "position": part_at})


func _press(point: Vector2) -> void:
	match _step:
		Step.PULL, Step.DRIVE:
			_active_nail = _find_nail(point)
			if _active_nail != -1:
				_pull_start_y = point.y + _heights[_active_nail] * pull_distance
				_pull_speed = 0.0

			_charge_time_passed = 0.0
		Step.REMOVE:
			_is_part_held = _part.has_point(point)
		Step.PLACE:
			_pick_option(point)


func _release() -> void:
	match _step:
		Step.PULL:
			_active_nail = -1
		Step.REMOVE:
			_is_part_held = false
			if not _is_part_removed:
				_part_offset = Vector2.ZERO
		Step.PLACE:
			_drop_option()
		Step.DRIVE:
			_hit_nail()


func _find_nail(point: Vector2) -> int:
	var found := -1
	for nail_index in _nails.size():
		var height := _heights[nail_index]
		var is_ready := height < 1.0 if _step == Step.PULL else height > NAIL_DRIVEN
		var head := _get_nail_head(nail_index)
		if is_ready and point.distance_to(head) <= NAIL_RADIUS * 3.0:
			found = nail_index
			break

	return found


func _get_nail_head(nail_index: int) -> Vector2:
	return _nails[nail_index] - Vector2(0.0, _heights[nail_index] * pull_distance * 0.6)


func _process_pull(mouse: Vector2, delta: float) -> void:
	if _active_nail == -1:
		return

	var speed := mouse.distance_to(_last_mouse) / maxf(delta, 0.001)
	_pull_speed = lerpf(_pull_speed, speed, minf(speed_smoothing * delta, 1.0))
	if _pull_speed > pull_max_speed:
		_active_nail = -1
		_add_mistake()
		return

	var pulled := (_pull_start_y - mouse.y) / pull_distance
	_heights[_active_nail] = clampf(pulled, _heights[_active_nail], 1.0)
	if _heights[_active_nail] >= 1.0:
		_active_nail = -1
		if _all_nails_out():
			_step = Step.REMOVE


func _all_nails_out() -> bool:
	var are_out := true
	for height in _heights:
		are_out = are_out and height >= 1.0

	return are_out


func _process_remove(mouse: Vector2) -> void:
	if not _is_part_held:
		return

	_part_offset += mouse - _last_mouse
	if _part_offset.length() >= remove_distance:
		_is_part_removed = true
		_is_part_held = false
		_step = Step.PLACE


func _pick_option(point: Vector2) -> void:
	for option_index in _options.size():
		var position_at: Vector2 = _options[option_index]["position"]
		if Rect2(position_at, _part.size).has_point(point):
			_held_option = option_index
			break


func _drop_option() -> void:
	if _held_option == -1:
		return

	var option: Dictionary = _options[_held_option]
	_held_option = -1
	var option_position: Vector2 = option["position"]
	if option_position.distance_to(_part.position) > snap_distance:
		option["position"] = option["home"]
	elif not is_equal_approx(option["share"], _notch_share):
		option["position"] = option["home"]
		_add_mistake()
	else:
		_is_new_part_set = true
		_start_driving()


func _start_driving() -> void:
	for nail_index in _heights.size():
		_heights[nail_index] = NAIL_STANDING

	_step = Step.DRIVE


## Сила удара: туда-обратно, чтобы нельзя было просто держать до упора.
func _get_charge() -> float:
	return pingpong(_charge_time_passed / charge_time, 1.0)


func _hit_nail() -> void:
	if _active_nail == -1:
		return

	var charge := _get_charge()
	var nail_index := _active_nail
	_active_nail = -1
	if charge >= charge_green_from and charge <= charge_green_to:
		_heights[nail_index] = NAIL_DRIVEN
	elif charge < charge_green_from:
		_heights[nail_index] = maxf(_heights[nail_index] - weak_hit_share, NAIL_DRIVEN)
	else:
		_add_mistake()

	if _all_nails_driven():
		_finish()


func _all_nails_driven() -> bool:
	var are_driven := true
	for height in _heights:
		are_driven = are_driven and height <= NAIL_DRIVEN

	return are_driven


func _add_mistake() -> void:
	_mistake_count += 1
	mistake_made.emit()


func _finish() -> void:
	_step = Step.DONE
	_is_running = false
	await get_tree().create_timer(finish_pause).timeout
	finished.emit(get_stars())


func _draw_lid() -> void:
	var lid := Rect2(lid_center - lid_size / 2.0, lid_size)
	draw_rect(lid, lid_color)
	var plank_step := lid_size.y / 4.0
	for plank in range(1, 4):
		var y := lid.position.y + plank_step * plank
		draw_line(Vector2(lid.position.x, y), Vector2(lid.end.x, y), plank_line_color, 4.0)

	draw_rect(lid, lid_edge_color, false, 12.0)
	var corners: Array[Vector2] = [
		lid.position,
		Vector2(lid.end.x, lid.position.y),
		lid.end,
		Vector2(lid.position.x, lid.end.y),
	]
	for corner in corners:
		draw_circle(corner, 38.0, corner_color)


## Где стоит часть: сломанная до снятия, дыра после, новая в конце.
func _draw_part_slot() -> void:
	if _is_new_part_set:
		_draw_part_shape(_part.position, _notch_share, _part_color)
		return

	if _step == Step.PLACE or _is_part_removed:
		_draw_part_shape(_part.position, _notch_share, hole_color)
		return

	_draw_part_shape(_part.position + _part_offset, _notch_share, _part_color.darkened(0.35))
	var center := _part.get_center() + _part_offset
	var half := _part.size.x * 0.35
	var crack := PackedVector2Array(
		[
			center + Vector2(-half, -10),
			center + Vector2(-half * 0.3, 14),
			center + Vector2(half * 0.2, -16),
			center + Vector2(half, 8),
		]
	)
	draw_polyline(crack, crack_color, 6.0, true)


## Часть с вырезом сверху: по нему видно, какая подходит.
func _draw_part_shape(corner: Vector2, share: float, color: Color) -> void:
	var size := _part.size
	var notch_x := size.x * share
	var points := PackedVector2Array(
		[
			corner,
			corner + Vector2(notch_x - NOTCH_WIDTH / 2.0, 0.0),
			corner + Vector2(notch_x, NOTCH_DEPTH),
			corner + Vector2(notch_x + NOTCH_WIDTH / 2.0, 0.0),
			corner + Vector2(size.x, 0.0),
			corner + size,
			corner + Vector2(0.0, size.y),
		]
	)
	draw_colored_polygon(points, color)
	points.append(corner)
	draw_polyline(points, lid_edge_color, 4.0, true)


func _draw_nail(nail_index: int) -> void:
	var height := _heights[nail_index]
	var bottom := _nails[nail_index]
	var head := _get_nail_head(nail_index)
	if height >= 1.0:
		return

	if height > NAIL_DRIVEN:
		draw_line(bottom, head, nail_color, NAIL_WIDTH)

	draw_circle(head, NAIL_RADIUS, nail_color)
	if _active_nail == nail_index and _step == Step.PULL:
		draw_line(head, head + Vector2(70.0, -90.0), pincers_color, 12.0, true)
		draw_line(head, head + Vector2(-70.0, -90.0), pincers_color, 12.0, true)


func _draw_charge() -> void:
	var head := _get_nail_head(_active_nail)
	var corner := head + Vector2(-CHARGE_BAR_SIZE.x / 2.0, -70.0)
	draw_rect(Rect2(corner, CHARGE_BAR_SIZE), charge_back_color)
	var green_x := CHARGE_BAR_SIZE.x * charge_green_from
	var green_width := CHARGE_BAR_SIZE.x * (charge_green_to - charge_green_from)
	var green := Rect2(corner + Vector2(green_x, 0.0), Vector2(green_width, CHARGE_BAR_SIZE.y))
	draw_rect(green, charge_green_color)
	var marker := corner.x + CHARGE_BAR_SIZE.x * _get_charge()
	var marker_top := Vector2(marker, corner.y - 8.0)
	var marker_bottom := Vector2(marker, corner.y + CHARGE_BAR_SIZE.y + 8.0)
	draw_line(marker_top, marker_bottom, charge_color, 6.0)
