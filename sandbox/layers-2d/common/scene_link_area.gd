class_name SceneLinkArea
extends ClickableArea
## Область на картинке, которая по клику открывает другую сцену.
## Может требовать предмет в инвентаре: без него только показывает надпись (#37).

@export_file("*.tscn") var target_scene: String
## Какой предмет нужен, чтобы открыть сцену (id из `common/items.json`). Пусто — не нужен.
@export var required_item: String = ""
## Надпись, если нужного предмета нет.
@export var missing_item_text: String = ""
## Надпись, пока сцены ещё нет (#40): например «Скоро». Пусто — только предупреждение.
@export var placeholder_text: String = ""


func _ready() -> void:
	super()
	clicked.connect(_on_clicked)


func _on_clicked() -> void:
	if target_scene.is_empty() and not placeholder_text.is_empty():
		SandboxHud.show_message(placeholder_text)
		return
	if target_scene.is_empty():
		push_warning("SceneLinkArea: не задана target_scene у %s" % name)
		return
	if not required_item.is_empty() and not SandboxState.has_item(required_item):
		SandboxHud.show_message(missing_item_text)
		return

	get_tree().change_scene_to_file(target_scene)
