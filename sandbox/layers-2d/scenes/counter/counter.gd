extends Node2D
## Прилавок (песочница, #37, #54): связывает посетителей и окно диалога.
## Стражник: первый разговор начинается сам, потом клик по нему открывает разговор о заказе.
## Ушёл стражник — приходит путник со своим заказом, всё так же.

const GUARD_LEAVE_EVENT := "guard_leave"
const TRAVELLER_AGREED_EVENT := "traveller_agreed"
const TRAVELLER_LEAVE_EVENT := "traveller_leave"
const GUARD_KEY := "guard"
const TRAVELLER_KEY := "traveller"

## Разговор о заказе, по клику на стражника.
@export_file("*.json") var order_dialogue_path: String
## Первый разговор с путником и разговор о его заказе.
@export_file("*.json") var traveller_intro_path: String
@export_file("*.json") var traveller_order_path: String

@onready var _guard: WalkingNpc = $NpcLayer/Guard
@onready var _guard_area: ClickableArea = $NpcLayer/Guard/Body/ClickArea
@onready var _traveller: WalkingNpc = $NpcLayer/Traveller
@onready var _traveller_area: ClickableArea = $NpcLayer/Traveller/Body/ClickArea
@onready var _dialogue_box: DialogueBox = $UI/DialogueBox


func _ready() -> void:
	# Стражник уже ушёл раньше — его не видно, и кликать не по кому.
	_guard_area.is_enabled = _guard.visible
	_traveller_area.is_enabled = false
	_guard_area.clicked.connect(_on_guard_area_clicked)
	_traveller_area.clicked.connect(_on_traveller_area_clicked)
	_traveller.arrived.connect(_on_traveller_arrived)
	_guard.left.connect(_traveller.walk_in)
	_dialogue_box.event_triggered.connect(_on_dialogue_box_event_triggered)
	if SandboxState.left_npcs.get(GUARD_KEY, false):
		_traveller.walk_in()


func _start_traveller_dialogue() -> void:
	var is_order_known: bool = SandboxState.finished_dialogues.get(TRAVELLER_KEY, false)
	_dialogue_box.anchor_node = _traveller
	_dialogue_box.start_other(traveller_order_path if is_order_known else traveller_intro_path)


func _on_guard_area_clicked() -> void:
	if _dialogue_box.visible or not _guard.is_standing():
		return

	_dialogue_box.start()
	if not _dialogue_box.visible:
		_dialogue_box.start_other(order_dialogue_path)


func _on_traveller_area_clicked() -> void:
	if _dialogue_box.visible or not _traveller.is_standing():
		return

	_start_traveller_dialogue()


func _on_traveller_arrived() -> void:
	_traveller_area.is_enabled = true
	if not SandboxState.finished_dialogues.get(TRAVELLER_KEY, false):
		_start_traveller_dialogue()


func _on_dialogue_box_event_triggered(event_name: String) -> void:
	match event_name:
		GUARD_LEAVE_EVENT:
			_guard_area.is_enabled = false
			_guard.walk_away()
		TRAVELLER_AGREED_EVENT:
			SandboxState.finished_dialogues[TRAVELLER_KEY] = true
		TRAVELLER_LEAVE_EVENT:
			_traveller_area.is_enabled = false
			_traveller.walk_away()
