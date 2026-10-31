class_name ChainGame
extends Node2D
## Мини-игра «кольчуга рыцаря» (песочница, #60): порвана цепь звеньев от левого края к правому.
## Клик поворачивает плитку: собери непрерывную цепь. Что уже связано с началом — горит.
## Поле, путь и лишние плитки каждый раз новые. Звёзды — за время.
## Вариант — в `common/items.json`: columns, rows, time_limit, price_bonus.

signal finished(stars: int)
@warning_ignore("unused_signal")
signal mistake_made

const STARS_MAX := 3
## Стороны плитки: биты, по часовой стрелке от верха.
const UP := 1
const RIGHT := 2
const DOWN := 4
const LEFT := 8
const DIRECTIONS: Array[int] = [UP, RIGHT, DOWN, LEFT]
const OFFSETS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const SIDE_COUNT := 4
const OPPOSITE_STEP := 2
const STRAIGHT := UP | DOWN
const CORNER := UP | RIGHT
const RING_POINTS := 24

@export var board_center: Vector2 = Vector2(960, 590)
@export var tile_size: float = 120.0
@export var finish_pause: float = 0.7
## Какая доля времени даёт 3 звезды; весь лимит — 2 звезды.
@export var three_stars_share: float = 0.55

@export_group("Вид")
@export var plate_color: Color = Color(0.09, 0.09, 0.11, 0.92)
@export var tile_color: Color = Color(0.2, 0.2, 0.23)
@export var hover_color: Color = Color(0.3, 0.3, 0.34)
@export var link_color: Color = Color(0.5, 0.52, 0.56)
@export var live_color: Color = Color(1.0, 0.78, 0.3)
@export var end_color: Color = Color(0.45, 0.85, 0.4)

var _is_running: bool = false
var _columns: int = 4
var _rows: int = 3
var _time_limit: float = 60.0
var _elapsed: float = 0.0
var _price_bonus: int = 0
var _start_row: int = 0
var _end_row: int = 0
## Плитки по рядам: биты открытых сторон.
var _tiles: Array[int] = []
var _connected: Dictionary[int, bool] = {}
var _has_won: bool = false


func _ready() -> void:
	hide()


func _process(delta: float) -> void:
	queue_redraw()
	if _is_running:
		_elapsed += delta


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if not _is_running or mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	get_viewport().set_input_as_handled()
	if mouse_event.pressed:
		_click(get_global_mouse_position())


func _draw() -> void:
	var board := _get_board_rect()
	draw_rect(board.grow(24.0), plate_color)
	var hovered := _get_index_at(get_global_mouse_position())
	for row in _rows:
		for column in _columns:
			_draw_tile(column, row, hovered)

	_draw_edge_link(_start_row, -1.0, live_color)
	var end_link_color := live_color if _has_won else end_color
	_draw_edge_link(_end_row, float(_columns), end_link_color)


## Начать по варианту из `items.json`.
func start(variant: Dictionary) -> void:
	_columns = int(variant.get("columns", 4))
	_rows = int(variant.get("rows", 3))
	_time_limit = variant.get("time_limit", 60.0)
	_price_bonus = int(variant.get("price_bonus", 0))
	_elapsed = 0.0
	_has_won = false
	_build_board()
	_update_connected()
	show()
	_is_running = true


func get_price_bonus() -> int:
	return _price_bonus


## Сколько звеньев уже в цепи от начала: доля от 0 до 1.
func get_progress_ratio() -> float:
	return float(_connected.size()) / maxf(_columns * _rows, 1.0)


## Сколько времени прошло: 1 — лимит вышел.
func get_tension() -> float:
	return clampf(_elapsed / _time_limit, 0.0, 1.0)


## Сколько звёзд выйдет, если закончить сейчас.
func get_stars() -> int:
	var stars := 1
	if _elapsed <= _time_limit * three_stars_share:
		stars = STARS_MAX
	elif _elapsed <= _time_limit:
		stars = 2

	return stars


## Проложить случайный путь слева направо, остальное заполнить плитками, всё повернуть.
func _build_board() -> void:
	_start_row = randi_range(0, _rows - 1)
	_tiles.clear()
	_tiles.resize(_columns * _rows)
	var path := _make_path()
	_end_row = path[-1].y
	for step in path.size():
		var cell := path[step]
		var from := cell + Vector2i.LEFT if step == 0 else path[step - 1]
		var to := cell + Vector2i.RIGHT if step == path.size() - 1 else path[step + 1]
		_tiles[_get_index(cell)] = _get_side(cell, from) | _get_side(cell, to)

	for index in _tiles.size():
		if _tiles[index] == 0:
			_tiles[index] = STRAIGHT if randf() < 0.5 else CORNER

		_tiles[index] = _rotated(_tiles[index], randi_range(0, SIDE_COUNT - 1))

	# Случайно собралось сразу — разбираем начало цепи.
	_update_connected()
	if _is_solved():
		_tiles[_get_index(path[0])] = _rotated(_tiles[_get_index(path[0])], 1)


## Случайный ход от левого края к правому: вправо, вверх или вниз, без самопересечений.
func _make_path() -> Array[Vector2i]:
	var cell := Vector2i(0, _start_row)
	var path: Array[Vector2i] = [cell]
	var last_row_move := 0
	while cell.x < _columns - 1:
		var choices: Array[int] = [0, 0]
		if cell.y > 0 and last_row_move != 1:
			choices.append(-1)

		if cell.y < _rows - 1 and last_row_move != -1:
			choices.append(1)

		var row_move: int = choices.pick_random()
		cell += Vector2i(0, row_move) if row_move != 0 else Vector2i.RIGHT
		last_row_move = row_move
		path.append(cell)

	return path


func _get_side(cell: Vector2i, other: Vector2i) -> int:
	return DIRECTIONS[OFFSETS.find(other - cell)]


func _get_index(cell: Vector2i) -> int:
	return cell.y * _columns + cell.x


func _rotated(tile: int, turns: int) -> int:
	var result := tile
	for _turn in turns:
		result = ((result << 1) & 15) | (result >> 3)

	return result


func _click(point: Vector2) -> void:
	var index := _get_index_at(point)
	if index == -1:
		return

	_tiles[index] = _rotated(_tiles[index], 1)
	_update_connected()
	if _is_solved():
		_finish()


func _get_board_rect() -> Rect2:
	var size := Vector2(_columns, _rows) * tile_size
	return Rect2(board_center - size / 2.0, size)


func _get_index_at(point: Vector2) -> int:
	var board := _get_board_rect()
	var index := -1
	if board.has_point(point):
		var cell := Vector2i((point - board.position) / tile_size)
		index = _get_index(cell)

	return index


## Обойти цепь от левого края: какие плитки с ним связаны.
func _update_connected() -> void:
	_connected.clear()
	var start := Vector2i(0, _start_row)
	if _tiles[_get_index(start)] & LEFT == 0:
		return

	var queue: Array[Vector2i] = [start]
	_connected[_get_index(start)] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for side in SIDE_COUNT:
			var next := cell + OFFSETS[side]
			if _can_link(cell, next, side) and not _connected.has(_get_index(next)):
				_connected[_get_index(next)] = true
				queue.append(next)


func _can_link(cell: Vector2i, next: Vector2i, side: int) -> bool:
	var is_inside := next.x >= 0 and next.x < _columns and next.y >= 0 and next.y < _rows
	if not is_inside or _tiles[_get_index(cell)] & DIRECTIONS[side] == 0:
		return false

	var opposite: int = DIRECTIONS[(side + OPPOSITE_STEP) % SIDE_COUNT]
	return _tiles[_get_index(next)] & opposite != 0


func _is_solved() -> bool:
	var end := Vector2i(_columns - 1, _end_row)
	return _connected.has(_get_index(end)) and _tiles[_get_index(end)] & RIGHT != 0


func _finish() -> void:
	_is_running = false
	_has_won = true
	await get_tree().create_timer(finish_pause).timeout
	finished.emit(get_stars())


func _draw_tile(column: int, row: int, hovered: int) -> void:
	var index := row * _columns + column
	var board := _get_board_rect()
	var corner := board.position + Vector2(column, row) * tile_size
	var rect := Rect2(corner, Vector2.ONE * tile_size).grow(-3.0)
	draw_rect(rect, hover_color if index == hovered and _is_running else tile_color)
	var color := live_color if _connected.has(index) else link_color
	var center := rect.get_center()
	for side in SIDE_COUNT:
		if _tiles[index] & DIRECTIONS[side] != 0:
			var edge := center + Vector2(OFFSETS[side]) * tile_size / 2.0
			_draw_link(center, edge, color)

	draw_arc(center, tile_size * 0.17, 0.0, TAU, RING_POINTS, color, 10.0, true)


## Звенья цепи: кольца вдоль линии.
func _draw_link(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(from, to, color, 10.0, true)
	draw_arc(from.lerp(to, 0.62), tile_size * 0.09, 0.0, TAU, RING_POINTS, color, 6.0, true)


func _draw_edge_link(row: int, column: float, color: Color) -> void:
	var board := _get_board_rect()
	var center := board.position + Vector2(column + 0.5, row + 0.5) * tile_size
	draw_arc(center, tile_size * 0.2, 0.0, TAU, RING_POINTS, color, 12.0, true)
	var inward := Vector2.RIGHT if column < 0.0 else Vector2.LEFT
	draw_line(center + inward * tile_size * 0.2, center + inward * tile_size * 0.5, color, 10.0)
