class_name RecipeMenu
extends VBoxContainer
## Кнопки рецептов одного места — наковальни, плавильни (#37, вынесено в #41).
## Рецепт, для которого нет нужного предмета, серый с подписью, чего не хватает.

signal recipe_chosen(recipe: Dictionary)

const BUTTON_SIZE := Vector2(480, 0)
const FONT_SIZE := 30

## Подпись к серому рецепту: чего не хватает.
@export var missing_item_prefix: String = "Требуется: "


## Показать рецепты места (`station` из `common/items.json`).
func fill(station: String) -> void:
	for child in get_children():
		child.queue_free()

	for recipe: Dictionary in SandboxState.get_recipes(station):
		add_child(_make_button(recipe))


func _make_button(recipe: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.text = recipe.get("name", "")
	var needed_item: String = recipe.get("needs", "")
	if not SandboxState.has_item(needed_item):
		var needed_info := SandboxState.get_item_info(needed_item)
		var needed_name: String = needed_info.get("name", needed_item)
		button.text += "\n" + missing_item_prefix + needed_name.to_lower()
		button.disabled = true

	button.pressed.connect(recipe_chosen.emit.bind(recipe))
	return button
