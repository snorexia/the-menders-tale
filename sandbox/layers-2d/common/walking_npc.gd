class_name WalkingNpc
extends Node2D
## Персонаж-картинка, который подходит к своему месту и стоит (песочница, #31).
## Ставь узел туда, где персонаж должен остановиться: он начнёт путь со сдвигом
## start_offset. Ноги не нужны — низ картинки прячется за слоем спереди.
## Шаги — покачивание вверх-вниз и наклон корпуса; стоя — лёгкое «дыхание».

signal arrived

enum State { WAITING, WALKING, STOPPING, STANDING }

const STOP_TIME := 0.35

## Откуда идёт, относительно места остановки, px.
@export var start_offset: Vector2 = Vector2(1100, 0)
## Через сколько секунд после открытия сцены начинает идти.
@export var start_delay: float = 1.0
## Скорость ходьбы, px в секунду.
@export var walk_speed: float = 260.0
## Длина шага, px: на каждый шаг — одно покачивание.
@export var step_length: float = 110.0
## Насколько поднимается на шаге, px.
@export var bob_height: float = 9.0
## Наклон корпуса на шаге, градусы.
@export var sway_degrees: float = 2.0
## «Дыхание» стоя: насколько растягивается по высоте (0.01 — на 1 %).
@export var breathe_amount: float = 0.008
## Скорость «дыхания»: вдохов в секунду.
@export var breathe_speed: float = 0.35

var _state: State = State.WAITING
var _target_position: Vector2
var _step_phase: float = 0.0
var _breathe_time: float = 0.0
var _body_scale: Vector2

@onready var _body: Node2D = $Body


func _ready() -> void:
	_body_scale = _body.scale
	_target_position = position
	position = _target_position + start_offset
	await get_tree().create_timer(start_delay).timeout
	_state = State.WALKING


func _process(delta: float) -> void:
	match _state:
		State.WALKING:
			_walk(delta)
		State.STANDING:
			_breathe(delta)


func _walk(delta: float) -> void:
	position = position.move_toward(_target_position, walk_speed * delta)
	_step_phase += walk_speed * delta / step_length * PI
	_body.position.y = -bob_height * absf(sin(_step_phase))
	_body.rotation = deg_to_rad(sway_degrees) * sin(_step_phase)
	if position.is_equal_approx(_target_position):
		_stop()


func _stop() -> void:
	_state = State.STOPPING
	var tween := create_tween().set_parallel().set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, "position:y", 0.0, STOP_TIME)
	tween.tween_property(_body, "rotation", 0.0, STOP_TIME)
	tween.chain().tween_callback(_on_stopped)


func _breathe(delta: float) -> void:
	_breathe_time += delta
	var stretch := breathe_amount * sin(_breathe_time * breathe_speed * TAU)
	_body.scale = _body_scale * Vector2(1.0, 1.0 + stretch)


func _on_stopped() -> void:
	_state = State.STANDING
	arrived.emit()
