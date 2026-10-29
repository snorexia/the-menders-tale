class_name MoltenPool
extends Node2D
## Заглушка крупного плана плавильни (#41): тигель сверху на углях, нарисован кодом,
## пока нет картинки дизайнера. По расплаву медленно плывут светлые блики.

const EMBER_COUNT := 140
const EMBER_SEED := 41
const SHIMMER_COUNT := 7
const RIM_WIDTH := 34.0
const WALL_WIDTH := 22.0
const SCREEN_SIZE := Vector2(1920, 1080)

## Центр тигля и радиус расплава, px.
@export var center: Vector2 = Vector2(960, 560)
@export var molten_radius: float = 330.0
## Скорость бликов на расплаве.
@export var shimmer_speed: float = 0.35

var _time: float = 0.0
var _embers: Array[Dictionary] = []


func _ready() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = EMBER_SEED
	for _ember_index in EMBER_COUNT:
		var ember := {
			"position": Vector2(random.randf() * SCREEN_SIZE.x, random.randf() * SCREEN_SIZE.y),
			"radius": random.randf_range(14.0, 46.0),
			"heat": random.randf(),
		}
		_embers.append(ember)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0.12, 0.05, 0.03))
	for ember: Dictionary in _embers:
		var color := Color(0.2, 0.08, 0.05).lerp(Color(0.85, 0.3, 0.08), ember["heat"])
		draw_circle(ember["position"], ember["radius"], color)

	var outer_radius := molten_radius + WALL_WIDTH + RIM_WIDTH
	draw_circle(center + Vector2(10, 16), outer_radius + 8.0, Color(0, 0, 0, 0.45))
	draw_circle(center, outer_radius, Color(0.42, 0.26, 0.16))
	draw_circle(center, outer_radius - RIM_WIDTH * 0.4, Color(0.52, 0.33, 0.2))
	draw_circle(center, molten_radius + WALL_WIDTH, Color(0.22, 0.1, 0.06))
	draw_circle(center, molten_radius, Color(0.95, 0.42, 0.08))
	draw_circle(center, molten_radius * 0.8, Color(1.0, 0.55, 0.14))
	draw_circle(center, molten_radius * 0.5, Color(1.0, 0.68, 0.25))
	_draw_shimmer()


func _draw_shimmer() -> void:
	for shimmer_index in SHIMMER_COUNT:
		var phase := _time * shimmer_speed + shimmer_index * TAU / SHIMMER_COUNT
		var orbit := molten_radius * (0.25 + 0.5 * fmod(shimmer_index * 0.37, 1.0))
		var offset := Vector2(cos(phase), sin(phase * 1.3)) * orbit
		var radius := molten_radius * (0.12 + 0.05 * sin(phase * 2.0))
		draw_circle(center + offset, radius, Color(1.0, 0.9, 0.55, 0.18))
