class_name MouseParallaxCamera
extends Camera2D
## Камера, которая слегка смещается вслед за мышью.
## Слои Parallax2D сдвигаются за ней с разной силой (scroll_scale) — появляется глубина.

## Наибольшее смещение камеры от центра, в пикселях (столько же сдвигается слой со scroll_scale 1).
@export var max_offset: Vector2 = Vector2(12.0, 6.0)
## Как быстро камера догоняет мышь: больше — резче.
@export var follow_speed: float = 4.0

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
