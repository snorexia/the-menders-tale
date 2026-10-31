class_name EmbroideryGame
extends Node2D
## Мини-игра «вышей герб» (песочница, #60): игла идёт по контуру рисунка, как подшив сумки.
## Каждый контур — отдельный шов `StitchSeam`; прошёл контур — он заливается цветом.
## Вариант — в `common/items.json`: cloth, shapes — контуры: points, fill, price_bonus.

signal finished(stars: int)
signal mistake_made

const STARS_MAX := 3
const HOOP_SEGMENTS := 96

@export var hoop_center: Vector2 = Vector2(960, 590)
@export var hoop_radius: float = 400.0
@export var stitch_spacing: float = 26.0
@export var max_speed: float = 520.0
@export var perfect_deviation: float = 11.0
@export var good_deviation: float = 22.0
@export var max_deviation: float = 42.0
@export var finish_pause: float = 0.6
@export var three_stars_from: float = 0.82
@export var two_stars_from: float = 0.55

@export_group("Вид")
@export var hoop_color: Color = Color(0.45, 0.28, 0.13)
@export var default_cloth_color: Color = Color(0.78, 0.72, 0.58)
@export var thread_color: Color = Color(0.95, 0.85, 0.5)

var _shapes: Array = []
var _shape_index: int = 0
var _seams: Array[StitchSeam] = []
var _fills: Array[Dictionary] = []
var _cloth_color: Color = Color.WHITE
var _price_bonus: int = 0


func _ready() -> void:
	hide()


func _draw() -> void:
	draw_circle(hoop_center, hoop_radius, _cloth_color)
	draw_arc(hoop_center, hoop_radius, 0.0, TAU, HOOP_SEGMENTS, hoop_color, 26.0, true)
	for fill: Dictionary in _fills:
		var points: PackedVector2Array = fill["points"]
		var is_simple := not Geometry2D.triangulate_polygon(points).is_empty()
		if is_simple:
			draw_colored_polygon(points, fill["color"])


## Начать по варианту из `items.json`.
func start(variant: Dictionary) -> void:
	_shapes = variant.get("shapes", [])
	_price_bonus = int(variant.get("price_bonus", 0))
	_cloth_color = Color(variant.get("cloth", default_cloth_color.to_html()))
	_shape_index = 0
	show()
	queue_redraw()
	_start_seam()


func get_price_bonus() -> int:
	return _price_bonus


## Сколько рисунка вышито: доля от 0 до 1.
func get_progress_ratio() -> float:
	var current := _seams[-1].get_progress_ratio() if not _seams.is_empty() else 0.0
	var done := _seams.size() - 1 + current
	return done / maxf(_shapes.size(), 1.0)


## Натяжение нитки текущего контура: доля от 0 до 1.
func get_tension() -> float:
	return _seams[-1].get_tension() if not _seams.is_empty() else 0.0


## Сколько звёзд выйдет, если закончить сейчас.
func get_stars() -> int:
	var total := 0.0
	for seam in _seams:
		total += seam.get_accuracy()

	var accuracy := total / maxf(_seams.size(), 1.0)
	var stars := 1
	if accuracy >= three_stars_from:
		stars = STARS_MAX
	elif accuracy >= two_stars_from:
		stars = 2

	return stars


func _start_seam() -> void:
	var shape: Dictionary = _shapes[_shape_index]
	var seam := StitchSeam.new()
	seam.stitch_spacing = stitch_spacing
	seam.max_speed = max_speed
	seam.perfect_deviation = perfect_deviation
	seam.good_deviation = good_deviation
	seam.max_deviation = max_deviation
	seam.thread_color = thread_color
	seam.finished.connect(_on_seam_finished)
	seam.mistake_made.connect(_on_seam_mistake_made)
	add_child(seam)
	_seams.append(seam)
	seam.start({"points": shape["points"], "no_tear": true, "closed": true})


func _on_seam_mistake_made() -> void:
	mistake_made.emit()


func _on_seam_finished(_stars: int) -> void:
	var shape: Dictionary = _shapes[_shape_index]
	var points := PackedVector2Array()
	for point: Array in shape["points"]:
		points.append(Vector2(point[0], point[1]))

	_fills.append({"points": points, "color": Color(shape.get("fill", "ffffff"))})
	queue_redraw()
	_shape_index += 1
	if _shape_index < _shapes.size():
		_start_seam()
	else:
		await get_tree().create_timer(finish_pause).timeout
		finished.emit(get_stars())
