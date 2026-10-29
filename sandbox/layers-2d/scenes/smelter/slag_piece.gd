class_name SlagPiece
extends Node2D
## Кусок шлака на расплаве (#41): всплывает, немного плавает и тонет.
## Кликнули, пока плавает, — снят. Утонул — не снят.

signal resolved(is_skimmed: bool)

const POINT_COUNT := 9
const CRUST_SCALE := 0.55
const CRUST_OFFSET := Vector2(-0.15, -0.2)
const HIT_RADIUS_SCALE := 1.2
const SKIM_TIME := 0.2
const SKIM_SCALE := 1.3
const SINK_SCALE := 0.4

## Радиус куска, px.
@export var radius: float = 46.0
## Сколько секунд всплывает, плавает и тонет.
@export var rise_time: float = 0.35
@export var float_time: float = 1.3
@export var sink_time: float = 0.5
## Скорость дрейфа по расплаву, px в секунду.
@export var drift_speed: float = 18.0

var _is_active: bool = false
var _drift: Vector2 = Vector2.ZERO
var _outline: PackedVector2Array = []
var _tween: Tween


func _ready() -> void:
	_outline = _make_outline()
	_drift = Vector2.from_angle(randf() * TAU) * drift_speed
	scale = Vector2.ZERO
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, rise_time).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_set_active.bind(true))
	_tween.tween_interval(float_time)
	_tween.tween_callback(_sink)


func _process(delta: float) -> void:
	position += _drift * delta


func _draw() -> void:
	draw_colored_polygon(_outline, Color(0.16, 0.12, 0.1))
	var crust := PackedVector2Array()
	for point in _outline:
		crust.append(point * CRUST_SCALE + CRUST_OFFSET * radius)

	draw_colored_polygon(crust, Color(0.32, 0.26, 0.22))
	var closed := _outline.duplicate()
	closed.append(_outline[0])
	draw_polyline(closed, Color(1.0, 0.6, 0.2, 0.7), 3.0)


## Снять кусок, если клик попал по нему, пока он плавает.
func try_skim(at_position: Vector2) -> bool:
	if not _is_active or at_position.distance_to(global_position) > radius * HIT_RADIUS_SCALE:
		return false

	_is_active = false
	_tween.kill()
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE * SKIM_SCALE, SKIM_TIME)
	tween.tween_property(self, "modulate:a", 0.0, SKIM_TIME)
	tween.chain().tween_callback(queue_free)
	resolved.emit(true)
	return true


func _make_outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in POINT_COUNT:
		var angle := TAU * point_index / POINT_COUNT + randf_range(-0.2, 0.2)
		points.append(Vector2.from_angle(angle) * radius * randf_range(0.7, 1.1))

	return points


func _set_active(value: bool) -> void:
	_is_active = value


func _sink() -> void:
	_is_active = false
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE * SINK_SCALE, sink_time)
	tween.tween_property(self, "modulate", Color(1.0, 0.6, 0.3, 0.0), sink_time)
	tween.chain().tween_callback(queue_free)
	resolved.emit(false)
