class_name GrinderWheel
extends Node2D
## Заглушка крупного плана точильного колеса (#42): каменное колесо сбоку
## в деревянной раме, низ колеса в корыте с водой. Нарисовано кодом, пока нет
## картинки дизайнера. Колесо крутится со скоростью `spin_speed`.

const SCREEN_SIZE := Vector2(1920, 1080)
const STREAK_COUNT := 14
const FLOOR_Y := 860.0
const POST_WIDTH := 46.0
const TROUGH_DEPTH := 150.0
const WATER_LINE := 0.82

## Центр и радиус колеса, px.
@export var center: Vector2 = Vector2(820, 500)
@export var radius: float = 330.0
## Скорость вращения, оборотов в секунду. Меняет сцена колеса.
@export var spin_speed: float = 0.0

var _angle: float = 0.0


func _process(delta: float) -> void:
	_angle += spin_speed * TAU * delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0.2, 0.15, 0.13))
	draw_rect(Rect2(0, FLOOR_Y, SCREEN_SIZE.x, SCREEN_SIZE.y - FLOOR_Y), Color(0.27, 0.2, 0.17))
	var wood := Color(0.42, 0.25, 0.13)
	var post_top := center.y - POST_WIDTH
	var post_height := FLOOR_Y - post_top
	var left_post_x := center.x - radius - POST_WIDTH * 1.5
	var right_post_x := center.x + radius + POST_WIDTH * 0.5
	draw_rect(Rect2(left_post_x, post_top, POST_WIDTH, post_height), wood)
	draw_rect(Rect2(right_post_x, post_top, POST_WIDTH, post_height), wood)
	var axle := Vector2(radius + POST_WIDTH, 0)
	draw_line(center - axle, center + axle, Color(0.3, 0.3, 0.32), 18.0)
	_draw_wheel()
	_draw_trough()


func _draw_wheel() -> void:
	draw_circle(center, radius, Color(0.66, 0.58, 0.47))
	draw_circle(center, radius * 0.93, Color(0.74, 0.66, 0.54))
	for streak_index in STREAK_COUNT:
		var angle := _angle + TAU * streak_index / STREAK_COUNT
		var from := center + Vector2.from_angle(angle) * radius * 0.35
		var to := center + Vector2.from_angle(angle + 0.15) * radius * 0.88
		draw_line(from, to, Color(0.6, 0.52, 0.42, 0.7), 6.0)

	draw_circle(center, radius * 0.12, Color(0.3, 0.3, 0.32))
	draw_circle(center, radius * 0.06, Color(0.18, 0.18, 0.2))


func _draw_trough() -> void:
	var water_top := center.y + radius * WATER_LINE
	var trough := Rect2(center.x - radius * 0.9, water_top - 20, radius * 1.8, TROUGH_DEPTH)
	var water := Rect2(trough.position.x, water_top, trough.size.x, trough.size.y - 20)
	draw_rect(water, Color(0.25, 0.4, 0.5, 0.85))
	draw_rect(trough, Color(0.4, 0.24, 0.12), false, 14.0)
	draw_rect(Rect2(trough.position.x, trough.end.y - 30, trough.size.x, 30), Color(0.36, 0.21, 0.1))
