class_name SceneLinkArea
extends Area2D
## Область на картинке, которая по клику открывает другую сцену.
## При наведении курсор становится рукой, а подсвечиваемый узел — светлее.

@export_file("*.tscn") var target_scene: String
## Что подсветить при наведении, например слой с предметом. Можно не задавать.
@export var highlight_target: CanvasItem
## Цвет подсветки: значения больше 1 делают картинку светлее.
@export var highlight_color: Color = Color(1.35, 1.3, 1.2)

var _normal_color: Color = Color.WHITE


func _ready() -> void:
	# Без этого Area2D не получает событий мыши (по умолчанию выключено у окна).
	get_viewport().physics_object_picking = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	if highlight_target != null:
		_normal_color = highlight_target.modulate


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _set_highlighted(is_highlighted: bool) -> void:
	if highlight_target == null:
		return

	highlight_target.modulate = highlight_color if is_highlighted else _normal_color


func _on_mouse_entered() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	_set_highlighted(true)


func _on_mouse_exited() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_set_highlighted(false)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if target_scene.is_empty():
		push_warning("SceneLinkArea: не задана target_scene у %s" % name)
		return

	get_tree().change_scene_to_file(target_scene)
