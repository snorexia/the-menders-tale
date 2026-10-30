extends Node2D
## Создание предмета одной сценой (песочница, #51): выбираешь, что сковать, куёшь, камера
## едет к колесу, там выбираешь заточку; в конце карточка с оценками и ценой.
## Материал тратится в конце: ушёл посреди — он остался.

## Рецепты какого места показывать — `station` в `common/items.json`.
const STATION := "anvil"
## Метка меча с отличной заточкой: заказчик на неё отзывается отдельно.
const EXCELLENT_EDGE_TAG := "excellent_edge"
const SCREEN_CENTER := Vector2(960, 540)

## Сколько секунд камера переезжает от наковальни к колесу.
@export var camera_move_time: float = 0.7

@export_group("Тексты")
@export var result_title_format: String = "Готово: %s"
@export var forge_rating_format: String = "Ковка — %s"
@export var edge_rating_format: String = "Заточка — %s"
@export var price_format: String = "Цена: %d мон."
## Качество в подсказке инвентаря: оценка ковки и заточки.
@export var item_quality_format: String = "ковка — %s, заточка — %s"

var _recipe: Dictionary = {}

@onready var _camera: Camera2D = $Camera
@onready var _anvil: Node2D = $Anvil
@onready var _grinder: Node2D = $Grinder
@onready var _create_panel: Control = %CreatePanel
@onready var _recipes: RecipeMenu = %Recipes
@onready var _result_card: Control = %ResultCard
@onready var _card_title: Label = %CardTitle
@onready var _forge_rating_label: Label = %ForgeRatingLabel
@onready var _edge_rating_label: Label = %EdgeRatingLabel
@onready var _price_label: Label = %PriceLabel
@onready var _again_button: Button = %AgainButton


func _ready() -> void:
	_grinder.hide()
	_result_card.hide()
	_again_button.pressed.connect(get_tree().reload_current_scene)
	_recipes.recipe_chosen.connect(_run_craft)
	_recipes.fill(STATION)


func _run_craft(recipe: Dictionary) -> void:
	_recipe = recipe
	_create_panel.hide()
	_anvil.start()
	var forge_rating: String = await _anvil.forged
	_anvil.set_ui_visible(false)

	_grinder.show()
	await _move_camera_to(_grinder)
	_anvil.hide()
	_grinder.start()
	var edge_rating: String = await _grinder.sharpened
	_grinder.set_ui_visible(false)
	_finish(forge_rating, edge_rating)


func _move_camera_to(stage: Node2D) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "position", stage.position + SCREEN_CENTER, camera_move_time)
	await tween.finished


func _finish(forge_rating: String, edge_rating: String) -> void:
	var needed_item: String = _recipe.get("needs", "")
	var crafted_item: String = _recipe.get("gives", "")
	var price := _get_price(forge_rating, edge_rating)
	if SandboxState.try_take_item(needed_item):
		var quality := item_quality_format % [forge_rating.to_lower(), edge_rating]
		var tag := EXCELLENT_EDGE_TAG if _grinder.is_excellent else ""
		SandboxState.add_item(crafted_item, quality, tag, price)

	var crafted_name: String = SandboxState.get_item_info(crafted_item).get("name", crafted_item)
	_card_title.text = result_title_format % crafted_name.to_lower()
	_forge_rating_label.text = forge_rating_format % forge_rating.to_lower()
	_edge_rating_label.text = edge_rating_format % edge_rating
	_price_label.text = price_format % price
	_again_button.visible = SandboxState.has_item(needed_item)
	_result_card.show()


## Цена по рецепту: монеты за оценку ковки плюс прибавка за оценку заточки.
func _get_price(forge_rating: String, edge_rating: String) -> int:
	var forge_price: int = _recipe.get("price_by_forge", {}).get(forge_rating, 0)
	var edge_bonus: int = _recipe.get("price_by_edge", {}).get(edge_rating, 0)
	return maxi(forge_price + edge_bonus, 0)
