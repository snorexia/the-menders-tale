extends Node2D
## Горн в сцене создания (#51): короткая сценка без участия игрока.
## Металл лежит на углях, разгорается и сообщает, что готов к ковке.

signal heated

## Сколько секунд греется.
@export var heat_time: float = 1.8
## Свечение металла в конце: накладывается сверху, прозрачность — сила.
@export var hot_glow: Color = Color(0.95, 0.22, 0.0, 0.6)
## Яркость света от металла в конце.
@export var light_energy_max: float = 0.7

@onready var _metal_glow: Polygon2D = $Background/MetalGlow
@onready var _heat_light: PointLight2D = $Background/HeatLight
@onready var _heat_sparks: CPUParticles2D = $Background/HeatSparks


## Разогреть металл; по окончании — сигнал `heated`.
func heat() -> void:
	_heat_sparks.emitting = true
	var tween := create_tween().set_parallel()
	tween.tween_property(_metal_glow, "color", hot_glow, heat_time)
	tween.tween_property(_heat_light, "energy", light_energy_max, heat_time)
	tween.chain().tween_callback(heated.emit)
