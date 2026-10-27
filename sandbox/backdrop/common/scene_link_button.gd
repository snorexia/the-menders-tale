class_name SceneLinkButton
extends Button
## Кнопка, которая по нажатию открывает другую сцену.

@export_file("*.tscn") var target_scene: String


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if target_scene.is_empty():
		push_warning("SceneLinkButton: не задана target_scene у %s" % name)
		return

	get_tree().change_scene_to_file(target_scene)
