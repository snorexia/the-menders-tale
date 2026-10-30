class_name SceneLinkArea
extends ClickableArea
## Область на картинке, которая по клику открывает другую сцену.
## Сцена открывается всегда: чего не хватает, показывает меню рецептов внутри неё.

@export_file("*.tscn") var target_scene: String
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

	get_tree().change_scene_to_file(target_scene)
