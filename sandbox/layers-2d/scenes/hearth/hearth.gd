extends Node2D
## Крупный план горна с мини-игрой нагрева (песочница, #28).
## Держишь кнопку — заготовка греется, отпустил — остывает, и нагрев проверяется:
## в зоне — хорошо, в середине зоны — идеально, выше зоны или до предела — мусор.
## Итог меняет инвентарь (#37): хорошо — заготовка становится нагретой, мусор — пропадает.
## Сначала выбираешь рецепт: что греем и что получаем — в `common/items.json`.

const PERCENT := 100.0
const HINT_FADE_TIME := 1.5
## Рецепты какого места показывать — `station` в `common/items.json`.
const STATION := "hearth"

## Скорость нагрева: доля шкалы в секунду (0.33 — полная шкала за 3 с).
@export var heat_speed: float = 0.33
## Скорость остывания, пока кнопка отпущена.
@export var cool_speed: float = 0.1
## Хороший нагрев: от и до, доли шкалы.
@export_range(0.0, 1.0) var good_from: float = 0.65
@export_range(0.0, 1.0) var good_to: float = 0.9
## Идеальный нагрев — середина хорошей зоны.
@export_range(0.0, 1.0) var perfect_from: float = 0.75
@export_range(0.0, 1.0) var perfect_to: float = 0.85
## С какого нагрева сыплются искры — предупреждение о перегреве.
@export_range(0.0, 1.0) var sparks_from: float = 0.88

@export_group("Вид")
## Цвет металла по нагреву: умножается на картинку заготовки.
@export var metal_gradient: Gradient
## Свечение металла по нагреву: накладывается сверху.
@export var glow_gradient: Gradient
## Яркость света от заготовки при полном нагреве.
@export var light_energy_max: float = 1.4

@export_group("Тексты")
@export var perfect_text: String = "Идеально нагрета"
@export var good_text: String = "Хорошо нагрета"
@export var trash_text: String = "Перегрел — мусор"
@export var cold_text: String = "Ещё холодная — грей дальше"
@export var perfect_color: Color = Color(1.0, 0.8, 0.3)
@export var good_color: Color = Color(0.55, 0.85, 1.0)
@export var trash_color: Color = Color(0.6, 0.55, 0.5)
## Надписи об инвентаре: получили нагретую заготовку и испортили заготовку.
@export var output_added_text: String = "В инвентаре: нагретая заготовка"
@export var input_lost_text: String = "Заготовка испорчена"

var _heat: float = 0.0
var _is_mouse_held: bool = false
var _was_heating: bool = false
var _is_finished: bool = false
var _hint_tween: Tween
var _recipe: Dictionary = {}

@onready var _metal_tint: Polygon2D = $Background/MetalTint
@onready var _metal_glow: Polygon2D = $Background/MetalGlow
@onready var _heat_light: PointLight2D = $Background/HeatLight
@onready var _heat_sparks: CPUParticles2D = $Background/HeatSparks
@onready var _heat_bar: ProgressBar = %HeatBar
@onready var _good_zone: Control = %GoodZone
@onready var _perfect_zone: Control = %PerfectZone
@onready var _status_label: Label = %StatusLabel
@onready var _hint: Label = $UI/Hint
@onready var _recipe_panel: Control = %RecipePanel
@onready var _recipes: RecipeMenu = %Recipes
@onready var _result_panel: Control = %ResultPanel
@onready var _quality_label: Label = %QualityLabel
@onready var _score_label: Label = %ScoreLabel


func _ready() -> void:
	_place_zone(_good_zone, good_from, good_to)
	_place_zone(_perfect_zone, perfect_from, perfect_to)
	# Заливку шкалы перекрашиваем по нагреву — у каждой сцены своя копия стиля.
	var fill_style: StyleBox = _heat_bar.get_theme_stylebox("fill").duplicate()
	_heat_bar.add_theme_stylebox_override("fill", fill_style)
	_start_heating()
	_hint.hide()
	_recipes.recipe_chosen.connect(_on_recipe_chosen)
	_recipes.fill(STATION)


func _process(delta: float) -> void:
	if _is_finished or _recipe.is_empty():
		return

	var is_heating := _is_mouse_held or Input.is_key_pressed(KEY_SPACE)
	if is_heating:
		_heat = minf(_heat + heat_speed * delta, 1.0)
	else:
		_heat = maxf(_heat - cool_speed * delta, 0.0)

	if _heat >= 1.0:
		_finish(trash_text, trash_color, false)
	elif _was_heating and not is_heating:
		_judge_release()

	_was_heating = is_heating
	_update_visuals()


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _recipe.is_empty():
		return

	_is_mouse_held = mouse_event.pressed
	get_viewport().set_input_as_handled()


func _start_heating() -> void:
	_heat = 0.0
	_is_mouse_held = false
	_was_heating = false
	_is_finished = false
	_result_panel.hide()
	_status_label.modulate.a = 0.0
	_update_visuals()


func _judge_release() -> void:
	if _heat < good_from:
		_show_status(cold_text)
	elif _heat >= perfect_from and _heat <= perfect_to:
		_finish(perfect_text, perfect_color, true)
	elif _heat <= good_to:
		_finish(good_text, good_color, true)
	else:
		_finish(trash_text, trash_color, false)


func _finish(quality_text: String, quality_color: Color, is_heated: bool) -> void:
	_is_finished = true
	_use_input_item(is_heated)
	var percent := roundi(_heat * PERCENT)
	_quality_label.text = quality_text
	_quality_label.label_settings.font_color = quality_color
	_score_label.text = "Нагрев: %d %%" % percent
	_result_panel.show()


func _update_visuals() -> void:
	_metal_tint.color = metal_gradient.sample(_heat)
	_metal_glow.color = glow_gradient.sample(_heat)
	_heat_light.energy = light_energy_max * _heat
	_heat_sparks.emitting = _heat >= sparks_from and not _is_finished
	_heat_bar.value = _heat * PERCENT

	var fill_style := _heat_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style != null:
		fill_style.bg_color = Color(glow_gradient.sample(_heat), 1.0)


func _show_status(text: String) -> void:
	_status_label.text = text
	_status_label.modulate.a = 1.0
	if _hint_tween != null:
		_hint_tween.kill()

	_hint_tween = create_tween()
	_hint_tween.tween_property(_status_label, "modulate:a", 0.0, HINT_FADE_TIME)


## Растягивает отметку зоны на шкале: доли шкалы from–to.
func _place_zone(zone: Control, from: float, to: float) -> void:
	zone.anchor_left = from
	zone.anchor_right = to
	zone.offset_left = 0.0
	zone.offset_right = 0.0


## Заготовка тратится при любом итоге; нагрел — взамен нагретая.
func _use_input_item(is_heated: bool) -> void:
	if not SandboxState.try_take_item(_recipe.get("needs", "")):
		return

	if is_heated:
		SandboxState.add_item(_recipe.get("gives", ""))
		SandboxHud.show_message(output_added_text)
	else:
		SandboxHud.show_message(input_lost_text)


func _on_recipe_chosen(recipe: Dictionary) -> void:
	_recipe = recipe
	_recipe_panel.hide()
	_hint.show()
