class_name WalkingNpc
extends Node2D
## Персонаж-картинка, который подходит к своему месту и стоит (песочница, #31).
## Ставь узел туда, где персонаж должен остановиться: он начнёт путь со сдвигом
## start_offset. Ноги не нужны — низ картинки прячется за слоем спереди.
## Шаги — покачивание вверх-вниз и наклон корпуса; стоя — лёгкое «дыхание».
## `walk_away()` — уходит туда, откуда пришёл, и пропадает (#37).

signal arrived
signal left

enum State { WAITING, WALKING, STOPPING, STANDING }

const STOP_TIME := 0.35

## Откуда идёт, относительно места остановки, px.
@export var start_offset: Vector2 = Vector2(1100, 0)
## Через сколько секунд начинает идти.
@export var start_delay: float = 1.0
## Скорость ходьбы, px в секунду.
@export var walk_speed: float = 420.0
## Длина шага, px: на каждый шаг — одно покачивание.
@export var step_length: float = 140.0
## Насколько поднимается на шаге, px.
@export var bob_height: float = 9.0
## Наклон корпуса на шаге, градусы.
@export var sway_degrees: float = 2.0
## «Дыхание» стоя: насколько растягивается по высоте (0.01 — на 1 %).
@export var breathe_amount: float = 0.008
## Скорость «дыхания»: вдохов в секунду.
@export var breathe_speed: float = 0.35
## Имя, под которым песочница помнит, что персонаж уже подошёл (вернёшься в сцену —
## он уже стоит на месте) или ушёл (его уже нет). Пусто — не помнить.
@export var memory_key: String = ""

var _state: State = State.WAITING
var _target_position: Vector2
var _destination: Vector2
var _is_leaving: bool = false
var _step_phase: float = 0.0
var _breathe_time: float = 0.0
var _body_scale: Vector2

@onready var _body: Node2D = $Body


func _ready() -> void:
	_body_scale = _body.scale
	_target_position = position
	_destination = position
	if _has_left_before():
		hide()
	elif _has_arrived_before():
		_state = State.STANDING
		arrived.emit.call_deferred()
	else:
		_walk_in()


## Подошёл и стоит на месте: не идёт и не уходит.
func is_standing() -> bool:
	return _state == State.STANDING


## Уйти туда, откуда пришёл, и пропасть.
func walk_away() -> void:
	if _state != State.STANDING:
		return

	_body.scale = _body_scale
	_destination = _target_position + start_offset
	_is_leaving = true
	_state = State.WALKING


func _walk_in() -> void:
	position = _target_position + start_offset
	await get_tree().create_timer(start_delay).timeout
	_state = State.WALKING


func _has_arrived_before() -> bool:
	return not memory_key.is_empty() and SandboxState.arrived_npcs.get(memory_key, false)


func _has_left_before() -> bool:
	return not memory_key.is_empty() and SandboxState.left_npcs.get(memory_key, false)


func _process(delta: float) -> void:
	match _state:
		State.WALKING:
			_walk(delta)
		State.STANDING:
			_breathe(delta)


func _walk(delta: float) -> void:
	position = position.move_toward(_destination, walk_speed * delta)
	_step_phase += walk_speed * delta / step_length * PI
	_body.position.y = -bob_height * absf(sin(_step_phase))
	_body.rotation = deg_to_rad(sway_degrees) * sin(_step_phase)
	if not position.is_equal_approx(_destination):
		return

	if _is_leaving:
		_disappear()
	else:
		_stop()


func _stop() -> void:
	_state = State.STOPPING
	var tween := create_tween().set_parallel().set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, "position:y", 0.0, STOP_TIME)
	tween.tween_property(_body, "rotation", 0.0, STOP_TIME)
	tween.chain().tween_callback(_on_stopped)


func _disappear() -> void:
	_state = State.WAITING
	hide()
	if not memory_key.is_empty():
		SandboxState.left_npcs[memory_key] = true

	left.emit()


func _breathe(delta: float) -> void:
	_breathe_time += delta
	var stretch := breathe_amount * sin(_breathe_time * breathe_speed * TAU)
	_body.scale = _body_scale * Vector2(1.0, 1.0 + stretch)


func _on_stopped() -> void:
	_state = State.STANDING
	if not memory_key.is_empty():
		SandboxState.arrived_npcs[memory_key] = true

	arrived.emit()
