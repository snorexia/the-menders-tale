extends Node2D
## Прилавок (песочница, #37): связывает стражника и окно диалога.
## Первый разговор начинается сам, когда стражник подошёл; потом клик по стражнику
## открывает разговор о заказе. Отдал меч — стражник уходит.

const GUARD_LEAVE_EVENT := "guard_leave"

## Разговор о заказе, по клику на стражника.
@export_file("*.json") var order_dialogue_path: String

@onready var _guard: WalkingNpc = $NpcLayer/Guard
@onready var _guard_area: ClickableArea = $NpcLayer/Guard/Body/ClickArea
@onready var _dialogue_box: DialogueBox = $UI/DialogueBox


func _ready() -> void:
	# Стражник уже ушёл раньше — его не видно, и кликать не по кому.
	_guard_area.is_enabled = _guard.visible
	_guard_area.clicked.connect(_on_guard_area_clicked)
	_dialogue_box.event_triggered.connect(_on_dialogue_box_event_triggered)


func _on_guard_area_clicked() -> void:
	if _dialogue_box.visible or not _guard.is_standing():
		return

	_dialogue_box.start()
	if not _dialogue_box.visible:
		_dialogue_box.start_other(order_dialogue_path)


func _on_dialogue_box_event_triggered(event_name: String) -> void:
	if event_name != GUARD_LEAVE_EVENT:
		return

	_guard_area.is_enabled = false
	_guard.walk_away()
