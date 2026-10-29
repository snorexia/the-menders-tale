class_name ClickableArea
extends Area2D
## Область на картинке, по которой можно кликнуть (#37, вынесено из SceneLinkArea).
## При наведении курсор становится рукой, а подсвечиваемый узел — светлее.

signal clicked

## Что подсветить при наведении, например слой с предметом. Можно не задавать.
@export var highlight_target: CanvasItem
## Цвет подсветки: значения больше 1 делают картинку светлее.
@export var highlight_color: Color = Color(1.35, 1.3, 1.2)
## Выключенная область не подсвечивается и не реагирует на клик.
@export var is_enabled: bool = true:
	set = set_enabled

var _normal_color: Color = Color.WHITE
var _is_hovered: bool = false


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


func set_enabled(value: bool) -> void:
	is_enabled = value
	if is_node_ready():
		_update_hover()


func _update_hover() -> void:
	var is_highlighted := is_enabled and _is_hovered
	var cursor := Input.CURSOR_POINTING_HAND if is_highlighted else Input.CURSOR_ARROW
	Input.set_default_cursor_shape(cursor)
	if highlight_target != null:
		highlight_target.modulate = highlight_color if is_highlighted else _normal_color


func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_hover()


func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_hover()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not is_enabled:
		return

	clicked.emit()
