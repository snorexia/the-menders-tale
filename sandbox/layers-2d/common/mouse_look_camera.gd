class_name MouseLookCamera
extends Camera2D
## Камера осматривает комнату вслед за мышью: мышь у правого края — видна правая часть комнаты.
## Все слои двигаются вместе с картинкой, поэтому предметы не «отрываются» от стены.

## Наибольшее смещение камеры от центра, в пикселях. Не больше запаса картинки за краем экрана.
@export var max_offset: Vector2 = Vector2(110.0, 60.0)
## Как быстро камера догоняет мышь: больше — резче.
@export var follow_speed: float = 3.0

var _rest_position: Vector2


func _ready() -> void:
	_rest_position = position


func _process(delta: float) -> void:
	var viewport_rect := get_viewport_rect()
	var half_size := viewport_rect.size / 2.0
	var mouse_offset := get_viewport().get_mouse_position() - viewport_rect.get_center()
	var mouse_direction := mouse_offset / half_size
	var clamped_direction := mouse_direction.clamp(-Vector2.ONE, Vector2.ONE)
	var target := _rest_position + clamped_direction * max_offset
	position = position.lerp(target, 1.0 - exp(-follow_speed * delta))
