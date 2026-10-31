class_name GearsGame
extends Node2D
## Мини-игра «собери механизм» (песочница, #60): перетащи шестерёнки с подноса на оси, чтобы
## вращение дошло от главной шестерни слева до стрелки часов справа. Шестерни цепляются,
## только если зубцы касаются: ось подходит не под любой размер. Механизм каждый раз новый.
## Вариант — в `common/items.json`: chain (сколько осей в цепи), extra_gears, extra_pegs,
## time_limit, price_bonus.

signal finished(stars: int)
signal mistake_made

const STARS_MAX := 3
const RADII: Array[float] = [52.0, 76.0, 104.0]
const DRIVER_RADIUS := 76.0
const OUTPUT_RADIUS := 76.0
## Пределы угла между соседними осями, радианы.
const MAX_CHAIN_ANGLE := 0.9
const PLACE_TRIES := 40
const TOOTH_SPACING := 26.0
const TOOTH_SIZE := Vector2(16, 18)
const SPIN_SPEED := 1.3
const PEG_RADIUS := 12.0

@export var board_rect: Rect2 = Rect2(250, 190, 1420, 590)
@export var driver_position: Vector2 = Vector2(340, 480)
@export var tray_y: float = 890.0
@export var tray_left: float = 520.0
@export var tray_step: float = 215.0
## Как далеко от оси шестерня встаёт на неё, px.
@export var snap_distance: float = 70.0
## Допуск зацепления, px.
@export var mesh_tolerance: float = 5.0
@export var finish_pause: float = 1.4

@export_group("Качество")
@export var mistake_penalty: float = 0.13
@export var late_penalty: float = 0.3
@export var three_stars_from: float = 0.85
@export var two_stars_from: float = 0.6

@export_group("Вид")
@export var board_color: Color = Color(0.09, 0.07, 0.06, 0.88)
@export var gear_color: Color = Color(0.62, 0.5, 0.28)
@export var live_gear_color: Color = Color(0.95, 0.74, 0.3)
@export var fixed_gear_color: Color = Color(0.5, 0.56, 0.62)
@export var peg_color: Color = Color(0.82, 0.8, 0.72)
@export var held_color: Color = Color(1.0, 0.9, 0.55)
@export var hand_color: Color = Color(0.9, 0.3, 0.2)

var _is_running: bool = false
## Шестерни: {"radius": ..., "position": ..., "home": ..., "peg": индекс или -1, "angle": ...}.
var _gears: Array[Dictionary] = []
var _pegs: PackedVector2Array = PackedVector2Array()
## Какие шестерни сейчас крутятся: индекс — направление и скорость.
var _spins: Dictionary[int, float] = {}
var _held: int = -1
var _held_offset: Vector2 = Vector2.ZERO
var _output_position: Vector2 = Vector2.ZERO
var _output_angle: float = 0.0
var _driver_angle: float = 0.0
var _output_spin: float = 0.0
var _time_limit: float = 90.0
var _elapsed: float = 0.0
var _mistake_count: int = 0
var _price_bonus: int = 0


func _ready() -> void:
	hide()


func _process(delta: float) -> void:
	queue_redraw()
	_driver_angle += SPIN_SPEED * delta
	_output_angle += _output_spin * delta
	for gear_index: int in _spins:
		_gears[gear_index]["angle"] += _spins[gear_index] * delta

	if not _is_running:
		return

	_elapsed += delta
	if _held != -1:
		_gears[_held]["position"] = get_global_mouse_position() + _held_offset


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if not _is_running or mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	get_viewport().set_input_as_handled()
	if mouse_event.pressed:
		_pick_gear(get_global_mouse_position())
	else:
		_drop_gear()


func _draw() -> void:
	draw_rect(board_rect.grow(14.0), board_color)
	for peg in _pegs:
		draw_circle(peg, PEG_RADIUS, peg_color)

	_draw_gear(driver_position, DRIVER_RADIUS, _driver_angle, fixed_gear_color)
	_draw_gear(_output_position, OUTPUT_RADIUS, _output_angle, fixed_gear_color)
	var hand := Vector2.from_angle(_output_angle) * OUTPUT_RADIUS * 0.95
	draw_line(_output_position, _output_position + hand, hand_color, 8.0, true)
	for gear_index in _gears.size():
		var gear: Dictionary = _gears[gear_index]
		var color := gear_color
		if gear_index == _held:
			color = held_color
		elif _spins.has(gear_index):
			color = live_gear_color

		_draw_gear(gear["position"], gear["radius"], gear["angle"], color)


## Начать по варианту из `items.json`.
func start(variant: Dictionary) -> void:
	_time_limit = variant.get("time_limit", _time_limit)
	_price_bonus = int(variant.get("price_bonus", 0))
	var chain := int(variant.get("chain", 3))
	_build(chain, int(variant.get("extra_gears", 1)), int(variant.get("extra_pegs", 1)))
	_elapsed = 0.0
	_mistake_count = 0
	_update_spins()
	show()
	_is_running = true


func get_price_bonus() -> int:
	return _price_bonus


## Сколько шестерён уже крутится: доля от 0 до 1.
func get_progress_ratio() -> float:
	return float(_spins.size()) / maxf(_pegs.size(), 1.0)


## Сколько времени прошло: 1 — лимит вышел.
func get_tension() -> float:
	return clampf(_elapsed / _time_limit, 0.0, 1.0)


## Сколько звёзд выйдет, если закончить сейчас.
func get_stars() -> int:
	var accuracy := 1.0 - mistake_penalty * _mistake_count
	if _elapsed > _time_limit:
		accuracy -= late_penalty

	var stars := 1
	if accuracy >= three_stars_from:
		stars = STARS_MAX
	elif accuracy >= two_stars_from:
		stars = 2

	return stars


func _build(chain: int, extra_gears: int, extra_pegs: int) -> void:
	_pegs.clear()
	_gears.clear()
	_spins.clear()
	var radii: Array[float] = []
	var current := driver_position
	var current_radius := DRIVER_RADIUS
	for _step in chain:
		var radius: float = RADII.pick_random()
		current = _next_position(current, current_radius + radius)
		current_radius = radius
		_pegs.append(current)
		radii.append(radius)

	_output_position = _next_position(current, current_radius + OUTPUT_RADIUS)
	for _extra in extra_gears:
		radii.append(RADII.pick_random())

	for _extra in extra_pegs:
		_add_extra_peg()

	radii.shuffle()
	for gear_index in radii.size():
		var home := Vector2(tray_left + tray_step * gear_index, tray_y)
		_gears.append(
			{"radius": radii[gear_index], "position": home, "home": home, "peg": -1, "angle": 0.0}
		)


## Следующая ось: правее, в пределах поля. Не вышло случайно — идём прямо вправо.
func _next_position(from: Vector2, distance: float) -> Vector2:
	var result := from + Vector2.RIGHT * distance
	for _try in PLACE_TRIES:
		var angle := randf_range(-MAX_CHAIN_ANGLE, MAX_CHAIN_ANGLE)
		var candidate := from + Vector2.from_angle(angle) * distance
		if board_rect.grow(-40.0).has_point(candidate):
			result = candidate
			break

	return result


func _add_extra_peg() -> void:
	for _try in PLACE_TRIES:
		var candidate := Vector2(
			randf_range(board_rect.position.x + 80.0, board_rect.end.x - 80.0),
			randf_range(board_rect.position.y + 60.0, board_rect.end.y - 60.0)
		)
		var is_free := candidate.distance_to(_output_position) > 200.0
		is_free = is_free and candidate.distance_to(driver_position) > 200.0
		for peg in _pegs:
			is_free = is_free and candidate.distance_to(peg) > 110.0

		if is_free:
			_pegs.append(candidate)
			break


func _pick_gear(point: Vector2) -> void:
	for gear_index in range(_gears.size() - 1, -1, -1):
		var gear: Dictionary = _gears[gear_index]
		var gear_position: Vector2 = gear["position"]
		if point.distance_to(gear_position) <= float(gear["radius"]):
			_held = gear_index
			_held_offset = gear_position - point
			gear["peg"] = -1
			_update_spins()
			break


func _drop_gear() -> void:
	if _held == -1:
		return

	var gear_index := _held
	_held = -1
	var gear: Dictionary = _gears[gear_index]
	var peg_index := _find_free_peg(gear["position"])
	if peg_index == -1:
		gear["position"] = gear["home"]
	elif _overlaps(_pegs[peg_index], gear["radius"], gear_index):
		gear["position"] = gear["home"]
		_mistake_count += 1
		mistake_made.emit()
	else:
		gear["peg"] = peg_index
		gear["position"] = _pegs[peg_index]

	_update_spins()
	if _output_spin != 0.0:
		_finish()


func _find_free_peg(point: Vector2) -> int:
	var found := -1
	for peg_index in _pegs.size():
		var is_taken := false
		for gear: Dictionary in _gears:
			is_taken = is_taken or gear["peg"] == peg_index

		if not is_taken and point.distance_to(_pegs[peg_index]) <= snap_distance:
			found = peg_index
			break

	return found


## Шестерня не влезает: упирается в соседнюю.
func _overlaps(point: Vector2, radius: float, ignored: int) -> bool:
	var is_blocked := _is_too_close(point, radius, driver_position, DRIVER_RADIUS)
	is_blocked = is_blocked or _is_too_close(point, radius, _output_position, OUTPUT_RADIUS)
	for gear_index in _gears.size():
		var gear: Dictionary = _gears[gear_index]
		if gear_index != ignored and gear["peg"] != -1:
			var other: Vector2 = gear["position"]
			is_blocked = is_blocked or _is_too_close(point, radius, other, gear["radius"])

	return is_blocked


func _is_too_close(point: Vector2, radius: float, other: Vector2, other_radius: float) -> bool:
	return point.distance_to(other) < radius + other_radius - mesh_tolerance


func _meshes(point: Vector2, radius: float, other: Vector2, other_radius: float) -> bool:
	return absf(point.distance_to(other) - radius - other_radius) <= mesh_tolerance


## Пустить вращение от главной шестерни: соседи крутятся в обратную сторону.
func _update_spins() -> void:
	_spins.clear()
	_output_spin = 0.0
	var queue: Array[Dictionary] = [
		{"position": driver_position, "radius": DRIVER_RADIUS, "speed": SPIN_SPEED}
	]
	while not queue.is_empty():
		var source: Dictionary = queue.pop_back()
		var source_speed: float = source["speed"]
		var speed_factor: float = source["radius"]
		for gear_index in _gears.size():
			var gear: Dictionary = _gears[gear_index]
			if gear["peg"] == -1 or _spins.has(gear_index):
				continue

			if _meshes(source["position"], source["radius"], gear["position"], gear["radius"]):
				var speed: float = -source_speed * speed_factor / float(gear["radius"])
				_spins[gear_index] = speed
				var next_source := {
					"position": gear["position"],
					"radius": gear["radius"],
					"speed": speed,
				}
				queue.append(next_source)

		var reaches_output := _meshes(
			source["position"], source["radius"], _output_position, OUTPUT_RADIUS
		)
		if reaches_output and _output_spin == 0.0:
			_output_spin = -source_speed * speed_factor / OUTPUT_RADIUS


func _finish() -> void:
	_is_running = false
	await get_tree().create_timer(finish_pause).timeout
	finished.emit(get_stars())


func _draw_gear(at: Vector2, radius: float, angle: float, color: Color) -> void:
	var tooth_count := maxi(roundi(TAU * radius / TOOTH_SPACING), 6)
	draw_circle(at, radius - TOOTH_SIZE.y * 0.5, color)
	for tooth in tooth_count:
		var tooth_angle := angle + TAU * tooth / tooth_count
		draw_set_transform(at, tooth_angle)
		var corner := Vector2(radius - TOOTH_SIZE.y, -TOOTH_SIZE.x / 2.0)
		draw_rect(Rect2(corner, Vector2(TOOTH_SIZE.y, TOOTH_SIZE.x)), color)

	draw_set_transform(Vector2.ZERO)
	draw_circle(at, radius * 0.5, color.darkened(0.25))
	draw_circle(at, PEG_RADIUS, peg_color)
