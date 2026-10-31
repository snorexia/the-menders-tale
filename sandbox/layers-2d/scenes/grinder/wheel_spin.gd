class_name WheelSpin
extends Node2D
## Вращение точильного камня поверх неподвижной картинки (#42).
## Камень на картинке нарисован с перспективой и перекрыт шатуном, поэтому крутим не
## саму картинку, а полупрозрачное «зерно» камня: оно рисуется только внутри лица
## камня (эллипс), выше воды, в обход шатуна и не заходя на втулку.

const ELLIPSE_POINTS := 64
const GRAIN_COUNT := 90
const GRAIN_SEED := 42
const GRAIN_LENGTH := 0.22

## Центр втулки и радиусы лица камня по горизонтали и вертикали, px картинки.
@export var center: Vector2 = Vector2(627, 313)
@export var radii: Vector2 = Vector2(240, 252)
## Ниже этой линии камень в воде — там не рисуем.
@export var water_line: float = 512.0
## Зерно не ближе этой доли радиуса к центру — там втулка.
@export_range(0.0, 1.0) var hub_ratio: float = 0.42
## Шатун педали поверх камня — многоугольник, px картинки.
@export var rod_polygon: PackedVector2Array = PackedVector2Array(
	[Vector2(614, 305), Vector2(662, 305), Vector2(748, 735), Vector2(698, 745)]
)
## Скорость вращения, оборотов в секунду. Меняет сцена колеса.
@export var spin_speed: float = 0.0
## Цвета зерна: тёмное и светлое.
@export var dark_grain: Color = Color(0.22, 0.15, 0.1, 0.55)
@export var light_grain: Color = Color(1.0, 0.9, 0.75, 0.4)

var _angle: float = 0.0
var _grains: Array[Dictionary] = []
var _spinners: Array[Node2D] = []


func _ready() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = GRAIN_SEED
	for _grain_index in GRAIN_COUNT:
		var grain := {
			"angle": random.randf() * TAU,
			"distance": random.randf_range(hub_ratio, 0.95),
			"width": random.randf_range(3.0, 7.0),
			"is_dark": random.randf() < 0.6,
		}
		_grains.append(grain)

	for mask_polygon in _build_masks():
		_add_spinner(mask_polygon)


func _process(delta: float) -> void:
	_angle += spin_speed * TAU * delta
	for spinner in _spinners:
		spinner.queue_redraw()


func _build_masks() -> Array[PackedVector2Array]:
	var face := PackedVector2Array()
	for point_index in ELLIPSE_POINTS:
		var angle := TAU * point_index / ELLIPSE_POINTS
		face.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))

	var above_water := PackedVector2Array(
		[
			center - radii * 2.0,
			Vector2(center.x + radii.x * 2.0, center.y - radii.y * 2.0),
			Vector2(center.x + radii.x * 2.0, water_line),
			Vector2(center.x - radii.x * 2.0, water_line),
		]
	)
	var masks: Array[PackedVector2Array] = []
	masks.assign(Geometry2D.intersect_polygons(face, above_water))
	return _cut(masks, rod_polygon)


func _cut(masks: Array[PackedVector2Array], hole: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for mask in masks:
		# Шатун выходит за край камня, поэтому дырок не бывает — только вырезы.
		result.append_array(Geometry2D.clip_polygons(mask, hole))

	return result


func _add_spinner(mask_polygon: PackedVector2Array) -> void:
	# Маска не рисуется сама, а только обрезает зерно по своей форме.
	var mask := Polygon2D.new()
	mask.polygon = mask_polygon
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var spinner := Node2D.new()
	spinner.draw.connect(_draw_grains.bind(spinner))
	mask.add_child(spinner)
	add_child(mask)
	_spinners.append(spinner)


func _draw_grains(spinner: Node2D) -> void:
	for grain in _grains:
		var angle: float = grain["angle"] + _angle
		var distance: float = grain["distance"]
		var from := center + Vector2(cos(angle), sin(angle)) * radii * distance
		var to_angle := angle + GRAIN_LENGTH
		var to := center + Vector2(cos(to_angle), sin(to_angle)) * radii * distance
		var color := dark_grain if grain["is_dark"] else light_grain
		spinner.draw_line(from, to, color, grain["width"])
