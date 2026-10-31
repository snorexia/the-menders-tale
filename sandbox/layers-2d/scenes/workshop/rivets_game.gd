class_name RivetsGame
extends Node2D
## Мини-игра «заклепай ремень» (песочница, #60): по шкале бежит бегунок, клик или пробел — удар.
## Зелёная зона — ровная заклёпка, жёлтая — сойдёт, мимо — погнулась, бей снова.
## С каждой заклёпкой бегунок быстрее, а зона уже и на новом месте. Вариант — в `items.json`.

signal finished(stars: int)
signal mistake_made

const STARS_MAX := 3
const RIVET_RADIUS := 15.0
const HOLE_RADIUS := 8.0
const PULSE_SPEED := 6.0
const HAMMER_ANGLE := -0.9
const HAMMER_HANDLE := Vector2(16, 150)
const HAMMER_HEAD := Vector2(90, 50)
const ZONE_MARGIN := 0.2

@export var belt_center: Vector2 = Vector2(960, 660)
## Заплатка поверх разрыва: половина ширины и высоты, px.
@export var patch_half_size: Vector2 = Vector2(235, 85)
@export var scale_rect: Rect2 = Rect2(560, 380, 800, 44)
## Насколько жёлтая зона шире зелёной.
@export var yellow_factor: float = 2.3
## На сколько ускоряется бегунок и сужается зона с каждой заклёпкой: доля.
@export var speed_step: float = 0.08
@export var zone_step: float = 0.05
## Сколько секунд длится удар: в это время новый удар не засчитывается.
@export var strike_time: float = 0.28
@export var finish_pause: float = 0.6

@export_group("Качество")
@export var perfect_score: float = 1.0
@export var good_score: float = 0.6
## Сколько снимает погнутая заклёпка.
@export var mistake_penalty: float = 0.12
@export var three_stars_from: float = 0.85
@export var two_stars_from: float = 0.6

@export_group("Тексты")
@export var perfect_text: String = "Точно!"
@export var good_text: String = "Сойдёт"
@export var bent_text: String = "Погнул"

@export_group("Вид")
@export var patch_color: Color = Color(0.2, 0.11, 0.06)
@export var patch_edge_color: Color = Color(0.75, 0.55, 0.32)
@export var hole_color: Color = Color(0.03, 0.02, 0.01)
@export var rivet_color: Color = Color(0.74, 0.72, 0.68)
@export var rivet_shine_color: Color = Color(0.95, 0.94, 0.9)
@export var pulse_color: Color = Color(1.0, 0.8, 0.3)
@export var scale_back_color: Color = Color(0.5, 0.14, 0.1)
@export var scale_yellow_color: Color = Color(0.85, 0.65, 0.2)
@export var scale_green_color: Color = Color(0.4, 0.8, 0.35)
@export var marker_color: Color = Color(1.0, 0.98, 0.9)
@export var hammer_handle_color: Color = Color(0.45, 0.28, 0.15)
@export var hammer_head_color: Color = Color(0.42, 0.42, 0.46)

var _is_running: bool = false
var _rivets: PackedVector2Array = PackedVector2Array()
var _scores: PackedFloat32Array = PackedFloat32Array()
var _next_index: int = 0
var _mistake_count: int = 0
var _price_bonus: int = 0
var _speed: float = 0.7
var _zone: float = 0.1
var _zone_center: float = 0.5
var _phase: float = 0.0
var _time: float = 0.0
var _strike_left: float = 0.0
var _feedback_text: String = ""
var _feedback_left: float = 0.0

@onready var _belt: Sprite2D = $Belt


func _ready() -> void:
	hide()
	_belt.show_behind_parent = true
	_belt.position = belt_center


func _process(delta: float) -> void:
	_time += delta
	_strike_left = maxf(_strike_left - delta, 0.0)
	_feedback_left = maxf(_feedback_left - delta, 0.0)
	queue_redraw()
	if _is_running and _strike_left <= 0.0:
		_phase += delta * _get_current_speed() * TAU


func _unhandled_input(event: InputEvent) -> void:
	if not _is_running:
		return

	var mouse_event := event as InputEventMouseButton
	var is_click := (
		mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	)
	if not is_click and not event.is_action_pressed("ui_accept"):
		return

	get_viewport().set_input_as_handled()
	if _strike_left <= 0.0:
		_strike()


func _draw() -> void:
	_draw_patch()
	for rivet_index in _rivets.size():
		var point := belt_center + _rivets[rivet_index]
		if rivet_index < _next_index:
			draw_circle(point, RIVET_RADIUS, rivet_color)
			draw_circle(point - Vector2.ONE * 4.0, RIVET_RADIUS * 0.35, rivet_shine_color)
		else:
			draw_circle(point, HOLE_RADIUS, hole_color)

	if _is_running:
		_draw_target()
		_draw_scale()

	if _strike_left > 0.0:
		_draw_hammer()

	if _feedback_left > 0.0:
		_draw_feedback()


## Начать по варианту: rivets — точки от центра ремня, speed, zone, price_bonus.
func start(variant: Dictionary) -> void:
	_rivets.clear()
	for point: Array in variant.get("rivets", []):
		_rivets.append(Vector2(point[0], point[1]))

	_speed = variant.get("speed", _speed)
	_zone = variant.get("zone", _zone)
	_price_bonus = int(variant.get("price_bonus", 0))
	_scores.clear()
	_next_index = 0
	_mistake_count = 0
	_pick_zone()
	show()
	_is_running = true


func get_price_bonus() -> int:
	return _price_bonus


## Сколько заклёпок поставлено: доля от 0 до 1.
func get_progress_ratio() -> float:
	return float(_next_index) / maxf(_rivets.size(), 1.0)


## Шкалы натяжения в этой игре нет.
func get_tension() -> float:
	return 0.0


## Сколько звёзд выйдет, если закончить сейчас.
func get_stars() -> int:
	var total := 0.0
	for score in _scores:
		total += score

	var mean := total / _scores.size() if not _scores.is_empty() else 1.0
	var accuracy := mean - mistake_penalty * _mistake_count
	var stars := 1
	if accuracy >= three_stars_from:
		stars = STARS_MAX
	elif accuracy >= two_stars_from:
		stars = 2

	return stars


func _get_current_speed() -> float:
	return _speed * (1.0 + speed_step * _next_index)


func _get_current_zone() -> float:
	return _zone * (1.0 - zone_step * _next_index)


func _get_marker() -> float:
	return 0.5 + 0.5 * sin(_phase)


func _pick_zone() -> void:
	_zone_center = randf_range(ZONE_MARGIN, 1.0 - ZONE_MARGIN)


func _strike() -> void:
	_strike_left = strike_time
	var distance := absf(_get_marker() - _zone_center)
	var zone := _get_current_zone()
	if distance <= zone:
		_set_rivet(perfect_score, perfect_text)
	elif distance <= zone * yellow_factor:
		_set_rivet(good_score, good_text)
	else:
		_mistake_count += 1
		_show_feedback(bent_text)
		mistake_made.emit()


func _set_rivet(score: float, text: String) -> void:
	_scores.append(score)
	_next_index += 1
	_show_feedback(text)
	if _next_index >= _rivets.size():
		_finish()
	else:
		_pick_zone()


func _show_feedback(text: String) -> void:
	_feedback_text = text
	_feedback_left = strike_time * 3.0


func _finish() -> void:
	_is_running = false
	await get_tree().create_timer(finish_pause).timeout
	finished.emit(get_stars())


func _draw_patch() -> void:
	var patch := Rect2(belt_center - patch_half_size, patch_half_size * 2.0)
	draw_rect(patch, patch_color)
	draw_rect(patch, patch_edge_color, false, 4.0)


func _draw_target() -> void:
	var point := belt_center + _rivets[_next_index]
	var pulse := 0.5 + 0.5 * sin(_time * PULSE_SPEED)
	draw_arc(point, RIVET_RADIUS + 6.0 + 8.0 * pulse, 0.0, TAU, 32, pulse_color, 4.0, true)


func _draw_scale() -> void:
	draw_rect(scale_rect, scale_back_color)
	var zone := _get_current_zone()
	_draw_scale_zone(zone * yellow_factor, scale_yellow_color)
	_draw_scale_zone(zone, scale_green_color)
	var marker_x := scale_rect.position.x + scale_rect.size.x * _get_marker()
	var top := Vector2(marker_x, scale_rect.position.y - 10.0)
	var bottom := Vector2(marker_x, scale_rect.end.y + 10.0)
	draw_line(top, bottom, marker_color, 6.0)


func _draw_scale_zone(half_share: float, color: Color) -> void:
	var from := clampf(_zone_center - half_share, 0.0, 1.0)
	var to := clampf(_zone_center + half_share, 0.0, 1.0)
	var left := scale_rect.position.x + scale_rect.size.x * from
	var width := scale_rect.size.x * (to - from)
	draw_rect(Rect2(left, scale_rect.position.y, width, scale_rect.size.y), color)


func _draw_hammer() -> void:
	var index := mini(_next_index, _rivets.size()) - 1
	var point := belt_center + (_rivets[maxi(index, 0)] if not _rivets.is_empty() else Vector2.ZERO)
	var share := _strike_left / strike_time
	draw_set_transform(point, HAMMER_ANGLE * share)
	var handle := Rect2(-HAMMER_HANDLE.x / 2.0, -HAMMER_HANDLE.y, HAMMER_HANDLE.x, HAMMER_HANDLE.y)
	draw_rect(handle, hammer_handle_color)
	var head_corner := Vector2(-HAMMER_HEAD.x / 2.0, -HAMMER_HANDLE.y - HAMMER_HEAD.y / 2.0)
	draw_rect(Rect2(head_corner, HAMMER_HEAD), hammer_head_color)
	draw_set_transform(Vector2.ZERO)


func _draw_feedback() -> void:
	var font := ThemeDB.fallback_font
	var at := Vector2(scale_rect.position.x, scale_rect.end.y + 70.0)
	var color := Color(marker_color, minf(_feedback_left * 3.0, 1.0))
	draw_string(
		font, at, _feedback_text, HORIZONTAL_ALIGNMENT_CENTER, scale_rect.size.x, 44, color
	)
