extends Node2D
## Крупный план наковальни с мини-игрой ковки (песочница, #25).
## Стадии сменяют картинку заготовки; на каждой по очереди сжимаются круги,
## клик в такт — удар засчитан. В конце качество меча — по доле попаданий.
## Сначала выбираешь, что сковать (#37): рецепт тратит нагретую заготовку и даёт меч.

const STAGE_FADE_TIME := 0.6
const FEEDBACK_RISE := 50.0
const FEEDBACK_TIME := 0.7
const FEEDBACK_SIZE := Vector2(240, 48)
const FLASH_ENERGY := 1.6
const FLASH_TIME := 0.25
const RING_PLACE_TRIES := 12
const PERCENT := 100.0
const RECIPE_BUTTON_SIZE := Vector2(480, 0)
const RECIPE_FONT_SIZE := 30

## Картинки стадий по порядку: заготовка → полоса → клинок.
@export var stage_textures: Array[Texture2D] = []
## Сколько кругов на одной стадии.
@export var rings_per_stage: int = 5
## Где появляются круги — прямоугольник поверх заготовки, в пикселях сцены.
@export var strike_area: Rect2 = Rect2(430, 470, 840, 75)
## Не ставить новый круг ближе этого к предыдущему, px.
@export var min_ring_distance: float = 180.0
## Пауза между кругами, с.
@export var pause_between_rings: float = 0.35
## Пауза перед стадией, с.
@export var pause_before_stage: float = 1.0

@export_group("Круг")
## Радиус круга в начале и в конце сжатия, px.
@export var ring_start_radius: float = 150.0
@export var ring_end_radius: float = 30.0
## Сколько секунд круг сжимается.
@export var ring_shrink_time: float = 0.75
## С какой доли сжатия клик засчитывается: 0.8 — последние 20 % времени.
@export_range(0.0, 1.0) var ring_hit_from: float = 0.8
## Сколько секунд сжатый круг ждёт клика.
@export var ring_late_time: float = 0.25

@export_group("Качество")
## Пороги доли попаданий, от лучшего: 1.0 — все, 0.75, 0.5. Ниже последнего — худшее.
@export var quality_thresholds: PackedFloat32Array = PackedFloat32Array([1.0, 0.75, 0.5])
## Названия качества: на одно больше, чем порогов.
@export var quality_names: PackedStringArray = PackedStringArray(
	["Высокая рарность", "Хорошее качество", "Плохое качество", "Мусор"]
)
@export var quality_colors: PackedColorArray = PackedColorArray(
	[
		Color(1.0, 0.8, 0.3),
		Color(0.55, 0.85, 1.0),
		Color(0.85, 0.75, 0.65),
		Color(0.6, 0.55, 0.5),
	]
)

@export_group("Тексты")
## Вид всплывающих надписей «Точно!» и др.
@export var feedback_settings: LabelSettings
@export var hit_text: String = "Точно!"
@export var early_text: String = "Рано"
@export var missed_text: String = "Мимо"
@export var late_text: String = "Не успел"
@export var hit_color: Color = Color(1.0, 0.9, 0.5)
@export var fail_color: Color = Color(0.8, 0.7, 0.65)
## Подпись к серому рецепту: чего не хватает.
@export var missing_item_prefix: String = "Требуется: "
## Заголовок итога: перед названием рецепта.
@export var result_title_prefix: String = "Выковано: "
@export var item_added_prefix: String = "В инвентаре: "

var _hit_count: int = 0
var _strike_count: int = 0
var _active_ring: StrikeRing
var _last_ring_position: Vector2 = Vector2.ZERO
var _recipe: Dictionary = {}

@onready var _background: Sprite2D = $Background
@onready var _next_background: Sprite2D = $NextBackground
@onready var _rings: Node2D = $Rings
@onready var _effects: Node2D = $Effects
@onready var _hit_sparks: CPUParticles2D = $HitSparks
@onready var _hit_flash: PointLight2D = $HitFlash
@onready var _title: Label = %Title
@onready var _hint: Label = $UI/Hint
@onready var _recipe_panel: Control = %RecipePanel
@onready var _recipes: VBoxContainer = %Recipes
@onready var _result_panel: Control = %ResultPanel
@onready var _quality_label: Label = %QualityLabel
@onready var _score_label: Label = %ScoreLabel


func _ready() -> void:
	_result_panel.hide()
	_hint.hide()
	_title.text = ""
	_show_recipes()


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or _active_ring == null:
		return

	get_viewport().set_input_as_handled()
	_active_ring.strike(get_global_mouse_position())


func _show_recipes() -> void:
	for recipe: Dictionary in SandboxState.recipes:
		var button := Button.new()
		button.custom_minimum_size = RECIPE_BUTTON_SIZE
		button.add_theme_font_size_override("font_size", RECIPE_FONT_SIZE)
		button.text = recipe.get("name", "")
		var needed_item: String = recipe.get("needs", "")
		if not SandboxState.has_item(needed_item):
			var needed_info := SandboxState.get_item_info(needed_item)
			var needed_name: String = needed_info.get("name", needed_item)
			button.text += "\n" + missing_item_prefix + needed_name.to_lower()
			button.disabled = true

		button.pressed.connect(_on_recipe_button_pressed.bind(recipe))
		_recipes.add_child(button)


func _start_forging() -> void:
	_hit_count = 0
	_strike_count = 0
	_recipe_panel.hide()
	_hint.show()
	_run_stages()


func _run_stages() -> void:
	for stage_index in stage_textures.size():
		_show_stage(stage_index)
		await get_tree().create_timer(pause_before_stage).timeout

		for _ring_index in rings_per_stage:
			_active_ring = _spawn_ring()
			var result: StrikeRing.Result = await _active_ring.resolved
			_active_ring = null
			_count_strike(result)
			await get_tree().create_timer(pause_between_rings).timeout

	_show_result()


func _show_stage(stage_index: int) -> void:
	var stage_number := stage_index + 1
	_title.text = "Ковка — стадия %d из %d" % [stage_number, stage_textures.size()]
	if stage_index == 0:
		_background.texture = stage_textures[stage_index]
	else:
		_fade_to_stage(stage_index)


func _fade_to_stage(stage_index: int) -> void:
	# Новая картинка проявляется поверх старой, потом становится основной.
	_next_background.texture = stage_textures[stage_index]
	_next_background.modulate.a = 0.0
	_next_background.show()
	var tween := create_tween()
	tween.tween_property(_next_background, "modulate:a", 1.0, STAGE_FADE_TIME)
	tween.tween_callback(_finish_stage_fade)


func _finish_stage_fade() -> void:
	_background.texture = _next_background.texture
	_next_background.hide()


func _spawn_ring() -> StrikeRing:
	var ring := StrikeRing.new()
	ring.start_radius = ring_start_radius
	ring.end_radius = ring_end_radius
	ring.shrink_time = ring_shrink_time
	ring.hit_from = ring_hit_from
	ring.late_time = ring_late_time
	ring.position = _pick_ring_position()
	_last_ring_position = ring.position
	_rings.add_child(ring)
	return ring


func _pick_ring_position() -> Vector2:
	var candidate := _random_point_in_strike_area()
	for _try_index in RING_PLACE_TRIES:
		if candidate.distance_to(_last_ring_position) >= min_ring_distance:
			break

		candidate = _random_point_in_strike_area()

	return candidate


func _random_point_in_strike_area() -> Vector2:
	var x := randf_range(strike_area.position.x, strike_area.end.x)
	var y := randf_range(strike_area.position.y, strike_area.end.y)
	return Vector2(x, y)


func _count_strike(result: StrikeRing.Result) -> void:
	_strike_count += 1
	var is_hit := result == StrikeRing.Result.HIT
	if is_hit:
		_hit_count += 1
		_play_hit_effects(_last_ring_position)

	var color := hit_color if is_hit else fail_color
	_show_feedback(_get_result_text(result), color, _last_ring_position)


func _get_result_text(result: StrikeRing.Result) -> String:
	var text := late_text
	match result:
		StrikeRing.Result.HIT:
			text = hit_text
		StrikeRing.Result.EARLY:
			text = early_text
		StrikeRing.Result.MISSED:
			text = missed_text

	return text


func _play_hit_effects(hit_position: Vector2) -> void:
	_hit_sparks.position = hit_position
	_hit_sparks.restart()
	_hit_flash.position = hit_position
	_hit_flash.energy = FLASH_ENERGY
	create_tween().tween_property(_hit_flash, "energy", 0.0, FLASH_TIME)


func _show_feedback(text: String, color: Color, at_position: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.label_settings = feedback_settings.duplicate()
	label.label_settings.font_color = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = FEEDBACK_SIZE
	label.position = at_position - FEEDBACK_SIZE / 2.0 - Vector2(0, ring_end_radius * 2.0)
	_effects.add_child(label)

	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - FEEDBACK_RISE, FEEDBACK_TIME)
	tween.tween_property(label, "modulate:a", 0.0, FEEDBACK_TIME)
	tween.chain().tween_callback(label.queue_free)


func _show_result() -> void:
	var hit_ratio := float(_hit_count) / maxf(_strike_count, 1.0)
	var quality_index := _get_quality_index(hit_ratio)
	var percent := roundi(hit_ratio * PERCENT)
	var recipe_name: String = _recipe.get("name", "")
	_title.text = result_title_prefix + recipe_name.to_lower()
	_quality_label.text = quality_names[quality_index]
	_quality_label.label_settings.font_color = quality_colors[quality_index]
	_score_label.text = "Попаданий: %d из %d (%d %%)" % [_hit_count, _strike_count, percent]
	_result_panel.show()
	_hint.hide()
	_craft(quality_names[quality_index])


func _get_quality_index(hit_ratio: float) -> int:
	var quality_index := quality_thresholds.size()
	for index in quality_thresholds.size():
		if hit_ratio >= quality_thresholds[index]:
			quality_index = index
			break

	return quality_index


## Заготовка тратится только в конце: ушёл посреди ковки — она осталась.
func _craft(quality: String) -> void:
	if not SandboxState.try_take_item(_recipe.get("needs", "")):
		return

	var crafted_item: String = _recipe.get("gives", "")
	SandboxState.add_item(crafted_item, quality)
	var crafted_name: String = SandboxState.get_item_info(crafted_item).get("name", crafted_item)
	SandboxHud.show_message(item_added_prefix + crafted_name.to_lower())


func _on_recipe_button_pressed(recipe: Dictionary) -> void:
	_recipe = recipe
	_start_forging()
