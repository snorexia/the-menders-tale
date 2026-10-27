class_name CameraSway
extends Camera3D
## Смотрит на точку и слегка поворачивается вслед за мышью — чтобы был виден объём.

@export var look_at_point: Vector3 = Vector3.ZERO
@export var max_angle_degrees: float = 2.0
@export var smoothing: float = 4.0

var _base_rotation: Vector3 = Vector3.ZERO
var _mouse_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	look_at(look_at_point)
	_base_rotation = rotation


func _process(delta: float) -> void:
	var max_angle := deg_to_rad(max_angle_degrees)
	var sway := Vector3(-_mouse_offset.y * max_angle, -_mouse_offset.x * max_angle, 0.0)
	rotation = rotation.lerp(_base_rotation + sway, clampf(smoothing * delta, 0.0, 1.0))


func _input(event: InputEvent) -> void:
	if event is not InputEventMouseMotion:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var mouse_position := (event as InputEventMouseMotion).position
	_mouse_offset = mouse_position / viewport_size * 2.0 - Vector2.ONE
