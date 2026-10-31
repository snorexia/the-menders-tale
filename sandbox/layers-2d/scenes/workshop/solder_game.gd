class_name SolderGame
extends Node2D
## Мини-игра «запаяй доспех» (песочница, #60): зажми кнопку и веди паяльник по трещинам.
## Медленно или стоишь на месте — металл перегревается, остаётся прожог. Быстро — шов не
## схватывается, вернись. Трещины ветвятся: пройди все ветки в любом порядке.
## Вариант — в `common/items.json`: plate (контур), cracks (линии), price_bonus.

signal finished(stars: int)
signal mistake_made

const STARS_MAX := 3
const SAMPLE_STEP := 10.0
const IRON_OFFSET := Vector2(70, -130)

## На каком расстоянии от паяльника трещина запаивается, px.
@export var reach: float = 30.0
## Скорость руки, при которой шов берётся, px в секунду.
@export var min_speed: float = 70.0
@export var max_speed: float = 620.0
## За сколько секунд на медленной руке появляется прожог.
@export var burn_time: float = 0.7
@export var heat_fall: float = 1.0
## Как плавно считается скорость руки.
@export var speed_smoothing: float = 12.0
@export var finish_pause: float = 0.7

@export_group("Качество")
@export var mistake_penalty: float = 0.15
@export var three_stars_from: float = 0.85
@export var two_stars_from: float = 0.6

@export_group("Вид")
@export var plate_color: Color = Color(0.42, 0.44, 0.48)
@export var plate_edge_color: Color = Color(0.72, 0.74, 0.78)
@export var crack_color: Color = Color(0.05, 0.04, 0.04)
@export var molten_color: Color = Color(1.0, 0.65, 0.2)
@export var cooled_color: Color = Color(0.82, 0.8, 0.7)
@export var burn_color: Color = Color(0.1, 0.06, 0.05, 0.85)
@export var iron_color: Color = Color(0.25, 0.25, 0.28)
@export var cool_time: float = 1.5

var _is_running: bool = false
var _is_holding: bool = false
var _plate: PackedVector2Array = PackedVector2Array()
var _samples: PackedVector2Array = PackedVector2Array()
## Сколько секунд назад запаян участок; -1 — ещё нет.
var _sealed_age: PackedFloat32Array = PackedFloat32Array()
var _sealed_count: int = 0
var _burns: PackedVector2Array = PackedVector2Array()
var _heat: float = 0.0
var _speed: float = 0.0
var _price_bonus: int = 0
var _last_mouse: Vector2 = Vector2.ZERO


func _ready() -> void:
	hide()


func _process(delta: float) -> void:
	queue_redraw()
	for index in _sealed_age.size():
		if _sealed_age[index] >= 0.0:
			_sealed_age[index] += delta

	if not _is_running:
		return

	var mouse := get_global_mouse_position()
	var current_speed := mouse.distance_to(_last_mouse) / maxf(delta, 0.001)
	_speed = lerpf(_speed, current_speed, minf(speed_smoothing * delta, 1.0))
	_last_mouse = mouse
	if _is_holding and _has_open_crack_near(mouse):
		_work(mouse, delta)
	else:
		_heat = maxf(_heat - heat_fall * delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if not _is_running or mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	get_viewport().set_input_as_handled()
	_is_holding = mouse_event.pressed
	_last_mouse = get_global_mouse_position()
	# С нуля: иначе простой клик сразу запаивал бы кусок трещины.
	_speed = 0.0


func _draw() -> void:
	if _plate.size() < 3:
		return

	draw_colored_polygon(_plate, plate_color)
	var outline := _plate.duplicate()
	outline.append(_plate[0])
	draw_polyline(outline, plate_edge_color, 8.0, true)
	for burn in _burns:
		draw_circle(burn, reach, burn_color)

	for index in _samples.size():
		draw_circle(_samples[index], 5.0, _get_sample_color(index))

	if _is_running:
		_draw_iron()


## Начать по варианту из `items.json`.
func start(variant: Dictionary) -> void:
	_plate = _to_points(variant.get("plate", []))
	_samples.clear()
	_sealed_age.clear()
	_sealed_count = 0
	_burns.clear()
	_heat = 0.0
	_price_bonus = int(variant.get("price_bonus", 0))
	for crack: Array in variant.get("cracks", []):
		_add_crack(_to_points(crack))

	show()
	_is_running = true


func get_price_bonus() -> int:
	return _price_bonus


## Сколько трещин запаяно: доля от 0 до 1.
func get_progress_ratio() -> float:
	return float(_sealed_count) / maxf(_samples.size(), 1.0)


## Перегрев металла: доля от 0 до 1.
func get_tension() -> float:
	return _heat


## Сколько звёзд выйдет, если закончить сейчас.
func get_stars() -> int:
	var accuracy := 1.0 - mistake_penalty * _burns.size()
	var stars := 1
	if accuracy >= three_stars_from:
		stars = STARS_MAX
	elif accuracy >= two_stars_from:
		stars = 2

	return stars


func _to_points(raw: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point: Array in raw:
		points.append(Vector2(point[0], point[1]))

	return points


func _add_crack(crack: PackedVector2Array) -> void:
	for segment in range(1, crack.size()):
		var from := crack[segment - 1]
		var to := crack[segment]
		var count := maxi(int(from.distance_to(to) / SAMPLE_STEP), 1)
		for step in count + 1:
			_samples.append(from.lerp(to, float(step) / count))
			_sealed_age.append(-1.0)


func _has_open_crack_near(mouse: Vector2) -> bool:
	var has_crack := false
	for index in _samples.size():
		if _sealed_age[index] < 0.0 and mouse.distance_to(_samples[index]) <= reach:
			has_crack = true
			break

	return has_crack


func _work(mouse: Vector2, delta: float) -> void:
	if _speed < min_speed:
		_heat += delta / burn_time
		if _heat >= 1.0:
			_burn(mouse)
		return

	_heat = maxf(_heat - heat_fall * delta, 0.0)
	if _speed <= max_speed:
		_seal(mouse)


func _burn(mouse: Vector2) -> void:
	_heat = 0.0
	_is_holding = false
	_burns.append(mouse)
	mistake_made.emit()


func _seal(mouse: Vector2) -> void:
	for index in _samples.size():
		if _sealed_age[index] < 0.0 and mouse.distance_to(_samples[index]) <= reach:
			_sealed_age[index] = 0.0
			_sealed_count += 1

	if _sealed_count >= _samples.size():
		_finish()


func _finish() -> void:
	_is_running = false
	_is_holding = false
	await get_tree().create_timer(finish_pause).timeout
	finished.emit(get_stars())


func _get_sample_color(index: int) -> Color:
	var age := _sealed_age[index]
	var color := crack_color
	if age >= 0.0:
		color = molten_color.lerp(cooled_color, minf(age / cool_time, 1.0))

	return color


func _draw_iron() -> void:
	var tip := get_global_mouse_position()
	draw_line(tip, tip + IRON_OFFSET, iron_color, 16.0, true)
	var tip_color := molten_color if _is_holding else iron_color
	draw_circle(tip, 10.0, tip_color)
