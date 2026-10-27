class_name FlickerLight3D
extends OmniLight3D
## Мерцание огня: яркость колеблется по плавному шуму вокруг исходной.

@export var flicker_strength: float = 0.25
@export var flicker_speed: float = 8.0

var _base_energy: float = 0.0
var _time: float = 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_base_energy = light_energy
	_noise.seed = randi()
	_noise.frequency = 0.5


func _process(delta: float) -> void:
	_time += delta * flicker_speed
	light_energy = _base_energy * (1.0 + _noise.get_noise_1d(_time) * flicker_strength)
