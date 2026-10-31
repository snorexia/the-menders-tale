class_name StitchSeam
extends Node2D
## Мини-игра подшива (песочница, #54): зажатой кнопкой мыши ведёшь иглу по пунктиру.
## Стежки ложатся там, где реально прошла игла: криво ведёшь — криво шьёшь.
## Линию шва и её сложность задаёт вариант из `common/items.json`, разрыв рисуется кодом.
## Слишком далеко от линии или слишком быстро — нитка рвётся, шов откатывается на стежок.
## Координаты — в пикселях картинки сумки: узел стоит в её левом верхнем углу.

signal finished(stars: int)
signal mistake_made

const DASH_LENGTH := 22.0
const DASH_GAP := 16.0
const DASH_SPEED := 40.0
const NEEDLE_LENGTH := 90.0
const NEEDLE_ANGLE := -0.9
const STITCH_HALF_WIDTH := 24.0
const STITCH_TILT := 0.45
const STARS_MAX := 3
const THREAD_SEGMENTS := 8
const THREAD_SAG := 26.0
const PULSE_SPEED := 5.0
const SMOOTH_PASSES := 3
const TEAR_STEP := 14.0
const TEAR_HALF_WIDTH := 15.0
const TEAR_FRAY_WIDTH := 7.0

## Линия шва вдоль разрыва, в пикселях картинки.
@export var path: PackedVector2Array = PackedVector2Array()
## Шаг между стежками, px.
@export var stitch_spacing: float = 46.0
## Откуда можно подхватить иглу: радиус вокруг текущей точки шва, px.
@export var grab_radius: float = 70.0
## Как далеко вперёд можно перескочить, чтобы шов засчитался, px.
@export var lookahead: float = 90.0

@export_group("Точность")
## До этого отклонения стежок ровный, до следующего — неплохой, px.
@export var perfect_deviation: float = 9.0
@export var good_deviation: float = 20.0
## Дальше этого отклонения нитка рвётся, px.
@export var max_deviation: float = 45.0
## Очки стежка: ровный, неплохой, кривой.
@export var perfect_score: float = 1.0
@export var good_score: float = 0.6
@export var crooked_score: float = 0.25
## Сколько очков (в доле от 1) снимает каждый обрыв нитки.
@export var snap_penalty: float = 0.08
## С какой итоговой точности 3 и 2 звезды.
@export var three_stars_from: float = 0.85
@export var two_stars_from: float = 0.6

@export_group("Натяжение")
## Быстрее этого нитка натягивается, px в секунду.
@export var max_speed: float = 320.0
## Как быстро растёт и спадает натяжение: доля шкалы в секунду.
@export var tension_rise: float = 2.2
@export var tension_fall: float = 0.9

@export_group("Вид")
@export var dash_color: Color = Color(1.0, 0.8, 0.3, 0.95)
@export var thread_color: Color = Color(0.88, 0.76, 0.55)
@export var tense_thread_color: Color = Color(1.0, 0.25, 0.15)
@export var thread_shadow_color: Color = Color(0.12, 0.07, 0.04, 0.8)
@export var needle_color: Color = Color(0.86, 0.88, 0.92)
@export var tear_color: Color = Color(0.05, 0.03, 0.02)
@export var tear_edge_color: Color = Color(0.62, 0.42, 0.26)

var _is_running: bool = false
var _is_holding: bool = false
var _progress: float = 0.0
var _next_stitch_at: float = 0.0
var _tension: float = 0.0
var _snap_count: int = 0
var _needle_position: Vector2 = Vector2.ZERO
var _last_position: Vector2 = Vector2.ZERO
var _time: float = 0.0
## Стежки: {"position": ..., "angle": ..., "score": ..., "at": ...}.
var _stitches: Array[Dictionary] = []
var _lengths: PackedFloat32Array = PackedFloat32Array()
## Края разрыва вдоль шва: {"left": ..., "right": ..., "fray": ..., "normal": ...}.
var _tear_points: Array[Dictionary] = []
var _price_bonus: int = 0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if not _is_running:
		return

	if _is_holding:
		advance(get_local_mouse_position(), delta)
	else:
		_tension = maxf(_tension - tension_fall * delta, 0.0)
		_needle_position = _get_point_at(_progress)


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if not _is_running or mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	get_viewport().set_input_as_handled()
	if not mouse_event.pressed:
		_is_holding = false
	elif get_local_mouse_position().distance_to(_get_point_at(_progress)) <= grab_radius:
		_is_holding = true
		_last_position = get_local_mouse_position()


func _draw() -> void:
	if path.size() < 2:
		return

	_draw_tear()
	_draw_dashes()
	for stitch in _stitches:
		_draw_stitch(stitch)

	if _is_running:
		_draw_grab_point()
		_draw_thread_and_needle()


## Начать шов по варианту: points, smooth, max_deviation, price_bonus.
func start(variant: Dictionary) -> void:
	_use_variant(variant)
	_stitches.clear()
	_progress = 0.0
	_next_stitch_at = stitch_spacing
	_tension = 0.0
	_snap_count = 0
	_is_holding = false
	_needle_position = _get_point_at(0.0)
	_is_running = true
	show()


## Сдвинуть иглу в точку: считает отклонение, натяжение и новые стежки.
func advance(needle_position: Vector2, delta: float) -> void:
	var speed := needle_position.distance_to(_last_position) / maxf(delta, 0.001)
	_last_position = needle_position
	_needle_position = needle_position
	if speed > max_speed:
		_tension = minf(_tension + tension_rise * delta, 1.0)
	else:
		_tension = maxf(_tension - tension_fall * delta, 0.0)

	var closest := _find_closest(needle_position)
	var deviation: float = closest["deviation"]
	if deviation > max_deviation or _tension >= 1.0:
		_snap()
		return

	_progress = maxf(_progress, closest["at"])
	while _next_stitch_at <= _progress:
		_add_stitch(_next_stitch_at, needle_position, deviation)
		_next_stitch_at += stitch_spacing

	if _progress >= get_total_length() - stitch_spacing * 0.5:
		_finish()


func get_total_length() -> float:
	return _lengths[-1] if not _lengths.is_empty() else 0.0


## Срезать углы линии несколько раз: она становится плавной, концы на месте.
static func smooth_path(points: PackedVector2Array) -> PackedVector2Array:
	var result := points
	for _pass_index in SMOOTH_PASSES:
		var next := PackedVector2Array([result[0]])
		for point_index in range(1, result.size()):
			next.append(result[point_index - 1].lerp(result[point_index], 0.25))
			next.append(result[point_index - 1].lerp(result[point_index], 0.75))

		next.append(result[-1])
		result = next

	return result


## Сколько монет этот разрыв прибавляет к цене.
func get_price_bonus() -> int:
	return _price_bonus


## Сколько шва пройдено: доля от 0 до 1.
func get_progress_ratio() -> float:
	return _progress / maxf(get_total_length(), 1.0)


## Натяжение нитки: доля от 0 до 1.
func get_tension() -> float:
	return _tension


## Точность шва: средняя оценка стежков минус обрывы.
func get_accuracy() -> float:
	var total := 0.0
	for stitch in _stitches:
		total += stitch["score"]

	var mean := total / _stitches.size() if not _stitches.is_empty() else 1.0
	return mean - snap_penalty * _snap_count


## Сколько звёзд выйдет, если закончить сейчас.
func get_stars() -> int:
	var accuracy := get_accuracy()
	var stars := 1
	if accuracy >= three_stars_from:
		stars = STARS_MAX
	elif accuracy >= two_stars_from:
		stars = 2

	return stars


func _use_variant(variant: Dictionary) -> void:
	var points := PackedVector2Array()
	for point: Array in variant.get("points", []):
		points.append(Vector2(point[0], point[1]))

	if variant.get("closed", false) and not points.is_empty():
		points.append(points[0])

	if not points.is_empty():
		path = smooth_path(points) if variant.get("smooth", false) else points

	max_deviation = variant.get("max_deviation", max_deviation)
	_price_bonus = int(variant.get("price_bonus", 0))
	_lengths = PackedFloat32Array([0.0])
	for point_index in range(1, path.size()):
		var segment := path[point_index].distance_to(path[point_index - 1])
		_lengths.append(_lengths[point_index - 1] + segment)

	_tear_points.clear()
	if not variant.get("no_tear", false):
		_build_tear()


func _build_tear() -> void:
	_tear_points.clear()
	var total := get_total_length()
	var count := maxi(int(total / TEAR_STEP), 2)
	for step_index in count + 1:
		var at := total * step_index / count
		var point := _get_point_at(at)
		var tangent := (_get_point_at(at + 1.0) - _get_point_at(at - 1.0)).normalized()
		var normal := tangent.orthogonal()
		# К концам разрыв сходится на нет, края рваные.
		var width := TEAR_HALF_WIDTH * sqrt(sin(PI * step_index / count))
		var tear_point := {
			"left": point + normal * (width + randf_range(-3.0, 4.0)),
			"right": point - normal * (width + randf_range(-3.0, 4.0)),
			"fray": randf_range(0.5, 1.0) * TEAR_FRAY_WIDTH,
			"normal": normal,
		}
		_tear_points.append(tear_point)


func _add_stitch(at: float, needle_position: Vector2, deviation: float) -> void:
	var score := crooked_score
	if deviation <= perfect_deviation:
		score = perfect_score
	elif deviation <= good_deviation:
		score = good_score

	var on_line := _get_point_at(at)
	# Стежок ложится туда, куда увела рука: чем дальше от линии, тем кривее.
	var offset := (needle_position - on_line).limit_length(deviation)
	var tangent := (_get_point_at(at + 1.0) - on_line).normalized()
	var skew := deviation / max_deviation * STITCH_TILT * signf(tangent.cross(offset))
	var stitch := {
		"position": on_line + offset,
		"angle": tangent.angle() + PI / 2.0 + STITCH_TILT + skew,
		"score": score,
		"at": at,
	}
	_stitches.append(stitch)


func _snap() -> void:
	_is_holding = false
	_snap_count += 1
	_tension = 0.0
	if not _stitches.is_empty():
		_stitches.pop_back()

	_progress = _stitches[-1]["at"] if not _stitches.is_empty() else 0.0
	_next_stitch_at = _progress + stitch_spacing
	_needle_position = _get_point_at(_progress)
	mistake_made.emit()


func _finish() -> void:
	_is_running = false
	_is_holding = false
	_progress = get_total_length()
	finished.emit(get_stars())


## Ближайшая к точке позиция на шве, не дальше `lookahead` от пройденного.
func _find_closest(point: Vector2) -> Dictionary:
	var limit := _progress + lookahead
	var back_limit := _progress - lookahead
	var best_at := _progress
	var best_deviation := point.distance_to(_get_point_at(_progress))
	for point_index in range(1, path.size()):
		var from := path[point_index - 1]
		var to := path[point_index]
		var on_segment := Geometry2D.get_closest_point_to_segment(point, from, to)
		var at := _lengths[point_index - 1] + from.distance_to(on_segment)
		var deviation := point.distance_to(on_segment)
		# На замкнутом контуре конец линии лежит рядом с началом: старые участки не считаем.
		var is_in_reach := at <= limit and at >= back_limit
		if is_in_reach and deviation <= best_deviation:
			best_at = at
			best_deviation = deviation

	return {"at": best_at, "deviation": best_deviation}


func _get_point_at(at: float) -> Vector2:
	var clamped := clampf(at, 0.0, get_total_length())
	var point := path[-1]
	for point_index in range(1, path.size()):
		if clamped <= _lengths[point_index]:
			var length := _lengths[point_index] - _lengths[point_index - 1]
			var ratio := (clamped - _lengths[point_index - 1]) / maxf(length, 0.001)
			point = path[point_index - 1].lerp(path[point_index], ratio)
			break

	return point


func _draw_tear() -> void:
	for index in range(1, _tear_points.size()):
		var before: Dictionary = _tear_points[index - 1]
		var after: Dictionary = _tear_points[index]
		var left_fray: Vector2 = after["normal"] * after["fray"]
		var right_fray: Vector2 = after["normal"] * -after["fray"]
		draw_line(before["left"], after["left"] + left_fray, tear_edge_color, 4.0)
		draw_line(before["right"], after["right"] + right_fray, tear_edge_color, 4.0)
		var middle_before: Vector2 = (before["left"] + before["right"]) / 2.0
		var middle_after: Vector2 = (after["left"] + after["right"]) / 2.0
		var width := maxf(before["left"].distance_to(before["right"]), 1.0)
		draw_line(middle_before, middle_after, tear_color, width)


func _draw_dashes() -> void:
	var total := get_total_length()
	var step := DASH_LENGTH + DASH_GAP
	var at := _progress + fmod(_time * DASH_SPEED, step)
	while at < total:
		var from := _get_point_at(at)
		var to := _get_point_at(minf(at + DASH_LENGTH, total))
		draw_line(from, to, Color(dash_color, dash_color.a * 0.3), 12.0)
		draw_line(from, to, dash_color, 5.0)
		at += step


func _draw_stitch(stitch: Dictionary) -> void:
	var center: Vector2 = stitch["position"]
	var half := Vector2.from_angle(stitch["angle"]) * STITCH_HALF_WIDTH
	draw_line(center - half, center + half, thread_shadow_color, 10.0)
	draw_line(center - half, center + half, thread_color, 6.0)


func _draw_grab_point() -> void:
	var point := _get_point_at(_progress)
	var pulse := 0.5 + 0.5 * sin(_time * PULSE_SPEED)
	if not _is_holding:
		draw_arc(point, 16.0 + 10.0 * pulse, 0.0, TAU, 32, dash_color, 4.0, true)

	draw_arc(path[-1], 12.0, 0.0, TAU, 24, dash_color, 4.0, true)
	draw_circle(path[-1], 4.0, dash_color)


func _draw_thread_and_needle() -> void:
	var color := thread_color.lerp(tense_thread_color, _tension)
	var from := _get_point_at(_progress)
	var sag := THREAD_SAG * (1.0 - _tension)
	var thread := PackedVector2Array()
	for segment_index in THREAD_SEGMENTS + 1:
		var ratio := float(segment_index) / THREAD_SEGMENTS
		var point := from.lerp(_needle_position, ratio)
		point.y += sin(ratio * PI) * sag
		thread.append(point)

	draw_polyline(thread, color, 4.0, true)
	var eye := _needle_position + Vector2.from_angle(NEEDLE_ANGLE) * NEEDLE_LENGTH
	draw_line(_needle_position, eye, thread_shadow_color, 9.0, true)
	draw_line(_needle_position, eye, needle_color, 5.0, true)
	draw_circle(eye, 5.0, needle_color)
