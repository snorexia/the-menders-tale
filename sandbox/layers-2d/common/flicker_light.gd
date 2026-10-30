class_name FlickerLight
extends PointLight2D
## Свет, который мерцает: яркость и размер пятна гуляют по плавному шуму.

## Насколько гуляет яркость: 0 — не мерцает, 0.3 — на ±30 %.
@export_range(0.0, 1.0) var strength: float = 0.25
## Насколько гуляет размер пятна света (доля от исходного).
@export_range(0.0, 0.5) var scale_strength: float = 0.05
## Скорость мерцания: больше — чаще дрожит.
@export var speed: float = 6.0

var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _base_energy: float
var _base_scale: float


func _ready() -> void:
	_base_energy = energy
	_base_scale = texture_scale
	_noise.seed = randi()


func _process(delta: float) -> void:
	_time += delta * speed
	var flicker := _noise.get_noise_1d(_time)
	energy = _base_energy * (1.0 + flicker * strength)
	texture_scale = _base_scale * (1.0 + flicker * scale_strength)
