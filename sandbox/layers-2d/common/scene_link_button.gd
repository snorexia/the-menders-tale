class_name SceneLinkButton
extends Button
## Кнопка, которая по нажатию открывает другую сцену.

@export_file("*.tscn") var target_scene: String
## Кнопка «назад»: срабатывает ещё и по Esc и правому клику.
@export var is_back_button: bool = false


func _ready() -> void:
	pressed.connect(_on_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not is_back_button:
		return

	var mouse_event := event as InputEventMouseButton
	var is_right_click := (
		mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT
	)
	if event.is_action_pressed("ui_cancel") or is_right_click:
		get_viewport().set_input_as_handled()
		_on_pressed()


func _on_pressed() -> void:
	if target_scene.is_empty():
		push_warning("SceneLinkButton: не задана target_scene у %s" % name)
		return

	get_tree().change_scene_to_file(target_scene)
