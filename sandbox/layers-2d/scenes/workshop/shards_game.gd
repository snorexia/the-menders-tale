class_name ShardsGame
extends Node2D
## Мини-игра «склей кувшин» (песочница, #60): осколки разбросаны по столу, тащи их на контур.
## Колесо или клавиша R поворачивают осколок. Осколки режутся кодом и каждый раз другие.
## Звёзды — от ошибок и от того, успел ли, пока клей не высох. Вариант — в `common/items.json`.

signal finished(stars: int)
signal mistake_made

const STARS_MAX := 3
const COVERAGE_SAMPLES := 16
## Клетка, где видно меньше этой доли картинки, не становится осколком.
const MIN_COVERAGE := 0.08
const ROTATE_STEP := PI / 4.0
const ROTATE_STEPS := 8
const ANGLE_TOLERANCE := 0.01
const CORNER_JITTER := 0.22
const EDGE_JITTER := 0.16
const CRACK_WIDTH := 3.0

@export var board_center: Vector2 = Vector2(960, 590)
## Во сколько пикселей вписать кувшин на столе.
@export var board_size: Vector2 = Vector2(700, 640)
## Где лежат осколки: слева и справа от кувшина, по X от края и по Y.
@export var scatter_left: Rect2 = Rect2(170, 240, 330, 640)
@export var scatter_right: Rect2 = Rect2(1420, 240, 330, 640)
## Как близко к месту осколок встаёт сам, px.
@export var snap_distance: float = 46.0
@export var fade_time: float = 0.8

@export_group("Качество")
## Сколько точности снимает ошибка и опоздание.
@export var mistake_penalty: float = 0.13
@export var late_penalty: float = 0.35
@export var three_stars_from: float = 0.85
@export var two_stars_from: float = 0.6

@export_group("Вид")
@export var ghost_color: Color = Color(0.05, 0.03, 0.02, 0.55)
## Контур с подсказкой: рисунок кувшина еле виден.
@export var picture_color: Color = Color(1.0, 1.0, 1.0, 0.3)
@export var crack_color: Color = Color(1.0, 0.8, 0.3, 0.35)
@export var held_color: Color = Color(1.25, 1.25, 1.1)

var _is_running: bool = false
var _can_rotate: bool = false
var _show_cracks: bool = false
var _glue_time: float = 60.0
var _elapsed: float = 0.0
var _mistake_count: int = 0
var _placed_count: int = 0
var _price_bonus: int = 0
var _scale: float = 1.0
var _held: Polygon2D
var _held_offset: Vector2 = Vector2.ZERO
var _shards: Array[Polygon2D] = []
## Куда встаёт каждый осколок.
var _targets: Dictionary[Polygon2D, Vector2] = {}
var _crack_lines: Array[PackedVector2Array] = []

@onready var _ghost: Sprite2D = $Ghost
@onready var _whole: Sprite2D = $Whole
@onready var _shard_layer: Node2D = $ShardLayer


func _ready() -> void:
	hide()
	_ghost.show_behind_parent = true


func _process(delta: float) -> void:
	if not _is_running:
		return

	_elapsed += delta
	if _held != null:
		_held.position = get_global_mouse_position() + _held_offset


func _unhandled_input(event: InputEvent) -> void:
	if not _is_running:
		return

	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and key_event.keycode == KEY_R:
		_rotate_shard(1)

	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return

	# Правую кнопку не трогаем: она у кнопки «К прилавку» работает как выход.
	match mouse_event.button_index:
		MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			if mouse_event.pressed:
				_pick_shard()
			else:
				_drop_shard()
		MOUSE_BUTTON_WHEEL_UP:
			if mouse_event.pressed:
				_rotate_shard(1)
		MOUSE_BUTTON_WHEEL_DOWN:
			if mouse_event.pressed:
				_rotate_shard(-1)


func _draw() -> void:
	if not _show_cracks:
		return

	for line in _crack_lines:
		draw_polyline(line, crack_color, CRACK_WIDTH, true)


## Начать по варианту: texture, pieces, glue_time, rotate, show_cracks, show_picture, price_bonus.
## Для витража: pieces_file — готовые контуры кусков, ghost_texture — рамка вместо контура.
func start(variant: Dictionary) -> void:
	var texture: Texture2D = load(variant.get("texture", ""))
	_can_rotate = variant.get("rotate", false)
	_show_cracks = variant.get("show_cracks", false)
	_glue_time = variant.get("glue_time", _glue_time)
	_price_bonus = int(variant.get("price_bonus", 0))
	var texture_size := texture.get_size()
	_scale = minf(board_size.x / texture_size.x, board_size.y / texture_size.y)
	for sprite: Sprite2D in [_ghost, _whole]:
		sprite.texture = texture
		sprite.position = board_center
		sprite.scale = Vector2.ONE * _scale

	var shows_picture: bool = variant.get("show_picture", false)
	_ghost.modulate = picture_color if shows_picture else ghost_color
	var ghost_path: String = variant.get("ghost_texture", "")
	if not ghost_path.is_empty():
		_ghost.texture = load(ghost_path)
		_ghost.modulate = Color.WHITE

	_whole.modulate.a = 0.0
	var pieces_path: String = variant.get("pieces_file", "")
	if pieces_path.is_empty():
		_build_shards(texture, int(variant.get("pieces", 6)))
	else:
		_load_shards(texture, pieces_path)

	_scatter_shards()
	queue_redraw()
	show()
	_is_running = true


func get_price_bonus() -> int:
	return _price_bonus


## Сколько осколков на месте: доля от 0 до 1.
func get_progress_ratio() -> float:
	return float(_placed_count) / maxf(_shards.size(), 1.0)


## Насколько высох клей: доля от 0 до 1.
func get_tension() -> float:
	return clampf(_elapsed / _glue_time, 0.0, 1.0)


## Сколько звёзд выйдет, если закончить сейчас.
func get_stars() -> int:
	var accuracy := 1.0 - mistake_penalty * _mistake_count
	if _elapsed > _glue_time:
		accuracy -= late_penalty

	var stars := 1
	if accuracy >= three_stars_from:
		stars = STARS_MAX
	elif accuracy >= two_stars_from:
		stars = 2

	return stars


## Куски заданы файлом: стёкла витража идут по свинцовым линиям.
func _load_shards(texture: Texture2D, path: String) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("ShardsGame: не удалось прочитать %s" % path)
		return

	for raw_polygon: Array in data.get("polygons", []):
		var polygon := PackedVector2Array()
		for point: Array in raw_polygon:
			polygon.append(Vector2(point[0], point[1]))

		_add_shard(texture, polygon, texture.get_size())


## Разрезать картинку сеткой со сдвинутыми узлами. Общие края у соседей совпадают.
func _build_shards(texture: Texture2D, pieces: int) -> void:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()

	var size := texture.get_size()
	var rows := maxi(roundi(sqrt(pieces * size.y / size.x)), 1)
	var columns := maxi(ceili(float(pieces) / rows), 1)
	var cell := Vector2(size.x / columns, size.y / rows)
	var corners := _make_corners(columns, rows, cell)
	var edges: Dictionary[String, Vector2] = {}
	for row in rows:
		for column in columns:
			var polygon := _make_cell(column, row, columns, corners, edges, cell)
			if _get_coverage(image, polygon) >= MIN_COVERAGE:
				_add_shard(texture, polygon, size)


func _make_corners(columns: int, rows: int, cell: Vector2) -> PackedVector2Array:
	var corners := PackedVector2Array()
	for row in rows + 1:
		for column in columns + 1:
			var corner := Vector2(column * cell.x, row * cell.y)
			var is_border := column in [0, columns] or row in [0, rows]
			if not is_border:
				corner += _random_offset(cell * CORNER_JITTER)

			corners.append(corner)

	return corners


func _random_offset(limit: Vector2) -> Vector2:
	return Vector2(randf_range(-limit.x, limit.x), randf_range(-limit.y, limit.y))


func _make_cell(
	column: int,
	row: int,
	columns: int,
	corners: PackedVector2Array,
	edges: Dictionary[String, Vector2],
	cell: Vector2,
) -> PackedVector2Array:
	var stride := columns + 1
	var top_left := corners[row * stride + column]
	var top_right := corners[row * stride + column + 1]
	var bottom_right := corners[(row + 1) * stride + column + 1]
	var bottom_left := corners[(row + 1) * stride + column]
	var jitter := cell * EDGE_JITTER
	var polygon := PackedVector2Array()
	polygon.append(top_left)
	polygon.append(_get_edge_middle("h%d_%d" % [row, column], top_left, top_right, jitter, edges))
	polygon.append(top_right)
	polygon.append(
		_get_edge_middle("v%d_%d" % [row, column + 1], top_right, bottom_right, jitter, edges)
	)
	polygon.append(bottom_right)
	polygon.append(
		_get_edge_middle("h%d_%d" % [row + 1, column], bottom_left, bottom_right, jitter, edges)
	)
	polygon.append(bottom_left)
	polygon.append(
		_get_edge_middle("v%d_%d" % [row, column], top_left, bottom_left, jitter, edges)
	)
	return polygon


## Излом посередине края. Запоминается, чтобы у соседнего осколка был тот же.
func _get_edge_middle(
	key: String, from: Vector2, to: Vector2, jitter: Vector2, edges: Dictionary[String, Vector2]
) -> Vector2:
	if not edges.has(key):
		edges[key] = (from + to) / 2.0 + _random_offset(jitter)

	return edges[key]


## Какая доля многоугольника непрозрачна.
func _get_coverage(image: Image, polygon: PackedVector2Array) -> float:
	var box := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		box = box.expand(point)

	var visible_count := 0
	var inside_count := 0
	for row in COVERAGE_SAMPLES:
		for column in COVERAGE_SAMPLES:
			var share := Vector2(column + 0.5, row + 0.5) / COVERAGE_SAMPLES
			var point := box.position + box.size * share
			if not Geometry2D.is_point_in_polygon(point, polygon):
				continue

			inside_count += 1
			var x := clampi(int(point.x), 0, image.get_width() - 1)
			var y := clampi(int(point.y), 0, image.get_height() - 1)
			if image.get_pixel(x, y).a > 0.5:
				visible_count += 1

	return float(visible_count) / maxf(inside_count, 1.0)


func _add_shard(texture: Texture2D, polygon: PackedVector2Array, size: Vector2) -> void:
	var center := Vector2.ZERO
	for point in polygon:
		center += point

	center /= polygon.size()
	var local_points := PackedVector2Array()
	for point in polygon:
		local_points.append(point - center)

	var shard := Polygon2D.new()
	shard.texture = texture
	shard.polygon = local_points
	shard.uv = polygon
	shard.scale = Vector2.ONE * _scale
	_shard_layer.add_child(shard)
	_shards.append(shard)
	_targets[shard] = board_center + (center - size / 2.0) * _scale

	var line := PackedVector2Array()
	for point in polygon:
		line.append(_targets[shard] + (point - center) * _scale)

	line.append(line[0])
	_crack_lines.append(line)


func _scatter_shards() -> void:
	_shards.shuffle()
	# Осколки лежат столбиками слева и справа, чтобы не закрывали друг друга.
	var row_count := ceili(_shards.size() / 2.0)
	for shard_index in _shards.size():
		var shard := _shards[shard_index]
		var area := scatter_left if shard_index % 2 == 0 else scatter_right
		var row_share := (floorf(shard_index / 2.0) + 0.5) / row_count
		var share := Vector2(randf(), row_share)
		shard.position = area.position + area.size * share
		if _can_rotate:
			shard.rotation = randi_range(1, ROTATE_STEPS - 1) * ROTATE_STEP


func _pick_shard() -> void:
	var mouse := get_global_mouse_position()
	var shard := _find_shard_at(mouse)
	if shard == null:
		return

	_held = shard
	_held_offset = shard.position - mouse
	_held.modulate = held_color
	_shard_layer.move_child(shard, -1)


func _find_shard_at(point: Vector2) -> Polygon2D:
	var found: Polygon2D = null
	for child in _shard_layer.get_children():
		var shard := child as Polygon2D
		if shard == null or _is_placed(shard):
			continue

		if Geometry2D.is_point_in_polygon(shard.to_local(point), shard.polygon):
			found = shard

	return found


func _is_placed(shard: Polygon2D) -> bool:
	return not _targets.has(shard)


func _drop_shard() -> void:
	if _held == null:
		return

	var shard := _held
	_held = null
	shard.modulate = Color.WHITE
	var target: Vector2 = _targets[shard]
	var is_near := shard.position.distance_to(target) <= snap_distance
	if is_near and absf(angle_difference(shard.rotation, 0.0)) < ANGLE_TOLERANCE:
		_place_shard(shard, target)
	elif _is_over_board(shard.position):
		_mistake_count += 1
		mistake_made.emit()


func _is_over_board(point: Vector2) -> bool:
	return Rect2(board_center - board_size / 2.0, board_size).has_point(point)


func _place_shard(shard: Polygon2D, target: Vector2) -> void:
	_targets.erase(shard)
	_placed_count += 1
	shard.position = target
	shard.rotation = 0.0
	_shard_layer.move_child(shard, 0)
	if _placed_count >= _shards.size():
		_finish()


func _rotate_shard(direction: int) -> void:
	if not _can_rotate:
		return

	var shard := _held if _held != null else _find_shard_at(get_global_mouse_position())
	if shard != null:
		shard.rotation = wrapf(shard.rotation + direction * ROTATE_STEP, -PI, PI)


func _finish() -> void:
	_is_running = false
	_show_cracks = false
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(_whole, "modulate:a", 1.0, fade_time)
	await tween.finished
	finished.emit(get_stars())
