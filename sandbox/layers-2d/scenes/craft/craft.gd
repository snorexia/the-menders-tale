extends Node2D
## Создание предмета одной сценой (песочница, #51): окно «Создать», потом камера едет
## горн → наковальня → колесо, в конце карточка с оценками. Материал тратится в конце:
## ушёл посреди — он остался.

## Рецепты какого места показывать — `station` в `common/items.json`.
const STATION := "anvil"
## Какой этап рецепт может отметить важным для заказа.
const SHARPEN_STAGE := "sharpen"
## Метка меча с отличной заточкой: за него заказчик доплачивает.
const EXCELLENT_EDGE_TAG := "excellent_edge"
const SCREEN_CENTER := Vector2(960, 540)
const UNSELECTED_MODULATE := Color(1.0, 1.0, 1.0, 0.55)

## Сколько секунд камера переезжает между этапами.
@export var camera_move_time: float = 0.7

@export_group("Тексты")
@export var heating_text: String = "Слиток греется в горне…"
@export var result_title_format: String = "Готово: %s"
@export var forge_rating_format: String = "Ковка — %s"
@export var edge_rating_format: String = "Заточка — %s"
## Качество в подсказке инвентаря: оценка ковки и заточки.
@export var item_quality_format: String = "ковка — %s, заточка — %s"

var _recipe: Dictionary = {}

@onready var _camera: Camera2D = $Camera
@onready var _hearth: Node2D = $Hearth
@onready var _anvil: Node2D = $Anvil
@onready var _grinder: Node2D = $Grinder
@onready var _stage_label: Label = %StageLabel
@onready var _create_panel: Control = %CreatePanel
@onready var _recipes: RecipeMenu = %Recipes
@onready var _by_hand_button: Button = %ByHandButton
@onready var _fast_button: Button = %FastButton
@onready var _important_label: Label = %ImportantLabel
@onready var _create_button: Button = %CreateButton
@onready var _result_card: Control = %ResultCard
@onready var _card_title: Label = %CardTitle
@onready var _forge_rating_label: Label = %ForgeRatingLabel
@onready var _edge_rating_label: Label = %EdgeRatingLabel
@onready var _again_button: Button = %AgainButton


func _ready() -> void:
	_hearth.hide()
	_grinder.hide()
	_result_card.hide()
	_stage_label.text = ""
	_important_label.hide()
	_create_button.disabled = true
	var sharpen_group := ButtonGroup.new()
	_by_hand_button.button_group = sharpen_group
	_fast_button.button_group = sharpen_group
	_by_hand_button.toggled.connect(_on_sharpen_mode_toggled)
	_fast_button.toggled.connect(_on_sharpen_mode_toggled)
	_by_hand_button.button_pressed = true
	_create_button.pressed.connect(_run_craft)
	_again_button.pressed.connect(get_tree().reload_current_scene)
	_recipes.recipe_chosen.connect(_select_recipe)
	_recipes.fill(STATION)
	_select_first_available_recipe()


func _select_first_available_recipe() -> void:
	for recipe: Dictionary in SandboxState.get_recipes(STATION):
		if SandboxState.has_item(recipe.get("needs", "")):
			_select_recipe(recipe)
			break


func _select_recipe(recipe: Dictionary) -> void:
	_recipe = recipe
	_create_button.disabled = false
	var is_sharpen_important := _is_sharpen_important(recipe)
	_important_label.visible = is_sharpen_important
	if is_sharpen_important:
		_by_hand_button.button_pressed = true


func _is_sharpen_important(recipe: Dictionary) -> bool:
	if recipe.get("important_stage", "") != SHARPEN_STAGE:
		return false

	return not SandboxState.left_npcs.get(recipe.get("important_for", ""), false)


func _run_craft() -> void:
	_create_panel.hide()
	_stage_label.text = heating_text
	_hearth.show()
	await _move_camera_to(_hearth)
	_hearth.heat()
	await _hearth.heated
	_stage_label.text = ""
	await _move_camera_to(_anvil)
	_hearth.hide()

	_anvil.start()
	var forge_rating: String = await _anvil.forged
	_anvil.set_ui_visible(false)

	var edge_rating: String = _grinder.medium_text
	if _by_hand_button.button_pressed:
		edge_rating = await _sharpen_by_hand()

	_finish(forge_rating, edge_rating)


func _sharpen_by_hand() -> String:
	_grinder.show()
	await _move_camera_to(_grinder)
	_anvil.hide()
	_grinder.start()
	var rating: String = await _grinder.sharpened
	_grinder.set_ui_visible(false)
	return rating


func _move_camera_to(stage: Node2D) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "position", stage.position + SCREEN_CENTER, camera_move_time)
	await tween.finished


func _finish(forge_rating: String, edge_rating: String) -> void:
	var needed_item: String = _recipe.get("needs", "")
	var crafted_item: String = _recipe.get("gives", "")
	if SandboxState.try_take_item(needed_item):
		var quality := item_quality_format % [forge_rating.to_lower(), edge_rating]
		var is_excellent: bool = _grinder.is_excellent and _by_hand_button.button_pressed
		SandboxState.add_item(crafted_item, quality, EXCELLENT_EDGE_TAG if is_excellent else "")

	var crafted_name: String = SandboxState.get_item_info(crafted_item).get("name", crafted_item)
	_card_title.text = result_title_format % crafted_name.to_lower()
	_forge_rating_label.text = forge_rating_format % forge_rating.to_lower()
	_edge_rating_label.text = edge_rating_format % edge_rating
	_again_button.visible = SandboxState.has_item(needed_item)
	_result_card.show()


func _on_sharpen_mode_toggled(_is_pressed: bool) -> void:
	_by_hand_button.modulate = Color.WHITE if _by_hand_button.button_pressed else UNSELECTED_MODULATE
	_fast_button.modulate = Color.WHITE if _fast_button.button_pressed else UNSELECTED_MODULATE
