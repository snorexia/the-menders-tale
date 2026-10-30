class_name RecipeMenu
extends VBoxContainer
## Кнопки рецептов одного места — наковальни, плавильни, мастерской (#37, вынесено в #41).
## Под названием всегда видно, что нужно и сколько есть. Без материала рецепт бледнее,
## а клик вместо начала работы показывает, чего не хватает.

signal recipe_chosen(recipe: Dictionary)

const BUTTON_SIZE := Vector2(480, 0)
const FONT_SIZE := 30
## Пока каждый рецепт тратит один предмет.
const NEEDED_COUNT := 1
const MISSING_ITEM_MODULATE := Color(1.0, 1.0, 1.0, 0.6)

## Подпись под рецептом: название материала, сколько есть, сколько нужно.
@export var needed_format: String = "Нужно: %s (есть %d из %d)"
## Надпись по клику на рецепт, для которого нет материала.
@export var missing_item_prefix: String = "Не хватает: "


## Показать рецепты места (`station` из `common/items.json`).
func fill(station: String) -> void:
	for child in get_children():
		child.queue_free()

	for recipe: Dictionary in SandboxState.get_recipes(station):
		add_child(_make_button(recipe))


func _make_button(recipe: Dictionary) -> Button:
	var needed_item: String = recipe.get("needs", "")
	var owned_count := SandboxState.count_item(needed_item)
	var needed_name := _get_item_name(needed_item)
	var button := Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.text = recipe.get("name", "")
	button.text += "\n" + needed_format % [needed_name, owned_count, NEEDED_COUNT]
	if owned_count < NEEDED_COUNT:
		button.modulate = MISSING_ITEM_MODULATE

	button.pressed.connect(_on_recipe_pressed.bind(recipe))
	return button


func _get_item_name(item_id: String) -> String:
	var item_name: String = SandboxState.get_item_info(item_id).get("name", item_id)
	return item_name.to_lower()


func _on_recipe_pressed(recipe: Dictionary) -> void:
	var needed_item: String = recipe.get("needs", "")
	if SandboxState.count_item(needed_item) < NEEDED_COUNT:
		SandboxHud.show_message(missing_item_prefix + _get_item_name(needed_item))
		return

	recipe_chosen.emit(recipe)
