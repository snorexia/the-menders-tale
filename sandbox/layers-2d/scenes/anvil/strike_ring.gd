class_name StrikeRing
extends Node2D
## Сужающийся круг мини-игры ковки: кликнуть надо, когда он почти сжался.
## Сам решает, засчитан ли клик, сообщает итог сигналом и исчезает.

signal resolved(result: Result)

enum Result { HIT, EARLY, MISSED, LATE }

const RING_SEGMENTS := 64
const GLOW_WIDTH_FACTOR := 3.0
const GLOW_ALPHA := 0.25
const FADE_TIME := 0.18
const FADE_SCALE := 1.25

## Радиус в начале, px.
var start_radius: float = 150.0
## Радиус в конце сжатия, px.
var end_radius: float = 30.0
## Сколько секунд круг сжимается.
var shrink_time: float = 0.9
## С какой доли сжатия клик засчитывается: 0.8 — последние 20 % времени.
var hit_from: float = 0.8
## Сколько секунд сжатый круг ждёт клика, прежде чем считается «не успел».
var late_time: float = 0.25
## Запас вокруг круга, в котором клик ещё считается попаданием, px.
var click_margin: float = 20.0
## Толщина линии круга, px.
var line_width: float = 5.0
## Цвет, пока бить рано.
var wait_color: Color = Color(1.0, 0.82, 0.55, 0.85)
## Цвет, когда пора бить.
var ready_color: Color = Color(1.0, 0.95, 0.7, 1.0)

var _elapsed: float = 0.0
var _is_resolved: bool = false


func _process(delta: float) -> void:
	if _is_resolved:
		return

	_elapsed += delta
	queue_redraw()
	if _elapsed >= shrink_time + late_time:
		_resolve(Result.LATE)


func _draw() -> void:
	var radius := get_radius()
	var color := ready_color if is_in_hit_window() else wait_color
	var glow_color := Color(color, color.a * GLOW_ALPHA)
	var glow_width := line_width * GLOW_WIDTH_FACTOR
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, RING_SEGMENTS, glow_color, glow_width, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, RING_SEGMENTS, color, line_width, true)


## Текущий радиус круга с учётом сжатия.
func get_radius() -> float:
	var progress := clampf(_elapsed / shrink_time, 0.0, 1.0)
	return lerpf(start_radius, end_radius, progress)


## Пора ли бить: круг сжался достаточно.
func is_in_hit_window() -> bool:
	return _elapsed >= shrink_time * hit_from


## Удар в точку экрана: засчитан, рано или мимо.
func strike(click_position: Vector2) -> void:
	if _is_resolved:
		return

	var distance := global_position.distance_to(click_position)
	if distance > get_radius() + click_margin:
		_resolve(Result.MISSED)
	elif not is_in_hit_window():
		_resolve(Result.EARLY)
	else:
		_resolve(Result.HIT)


func _resolve(result: Result) -> void:
	_is_resolved = true
	resolved.emit(result)

	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_property(self, "scale", Vector2.ONE * FADE_SCALE, FADE_TIME)
	tween.chain().tween_callback(queue_free)
