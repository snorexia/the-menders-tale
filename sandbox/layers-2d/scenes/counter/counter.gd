extends Node2D
## Прилавок (песочница, #37, #54): связывает посетителей и окно диалога.
## Посетители приходят сразу и ждут: клик по любому — первый разговор, потом разговор
## о заказе. Заказы можно брать и сдавать в любом порядке. Сдал заказ — посетитель уходит.

## События разговора: имя посетителя + окончание.
const AGREED_EVENT_SUFFIX := "_agreed"
const LEAVE_EVENT_SUFFIX := "_leave"

## Разговоры со стражником: первый и о заказе.
@export_file("*.json") var guard_intro_path: String
@export_file("*.json") var guard_order_path: String
## Разговоры с путником: первый и о заказе.
@export_file("*.json") var traveller_intro_path: String
@export_file("*.json") var traveller_order_path: String
## Где окно реплик относительно посетителя, px. Отрицательный X — окно слева от него.
## Стражник — слева, чтобы не закрыть путника; у путника окно ниже лица стражника.
@export var guard_box_offset: Vector2 = Vector2(-200, -600)
@export var traveller_box_offset: Vector2 = Vector2(-130, -447)
@export var talk_hint_text: String = "Кликни по посетителю, чтобы поговорить"

var _visitors: Array[Dictionary] = []
var _is_hint_shown: bool = false

@onready var _dialogue_box: DialogueBox = $UI/DialogueBox


func _ready() -> void:
	_add_visitor("guard", $NpcLayer/Guard, guard_intro_path, guard_order_path, guard_box_offset)
	_add_visitor(
		"traveller",
		$NpcLayer/Traveller,
		traveller_intro_path,
		traveller_order_path,
		traveller_box_offset
	)
	_dialogue_box.event_triggered.connect(_on_dialogue_box_event_triggered)


func _add_visitor(
	key: String, npc: WalkingNpc, intro_path: String, order_path: String, box_offset: Vector2
) -> void:
	var area: ClickableArea = npc.get_node("Body/ClickArea")
	area.is_enabled = false
	var visitor := {
		"key": key,
		"npc": npc,
		"area": area,
		"intro_path": intro_path,
		"order_path": order_path,
		"box_offset": box_offset,
	}
	_visitors.append(visitor)
	area.clicked.connect(_on_visitor_clicked.bind(visitor))
	npc.arrived.connect(_on_visitor_arrived.bind(visitor))


func _on_visitor_arrived(visitor: Dictionary) -> void:
	visitor["area"].is_enabled = true
	if not _is_hint_shown:
		_is_hint_shown = true
		SandboxHud.show_message(talk_hint_text)


func _on_visitor_clicked(visitor: Dictionary) -> void:
	var npc: WalkingNpc = visitor["npc"]
	if _dialogue_box.visible or not npc.is_standing():
		return

	var is_order_known: bool = SandboxState.finished_dialogues.get(visitor["key"], false)
	var path: String = visitor["order_path"] if is_order_known else visitor["intro_path"]
	_dialogue_box.start(path, npc, visitor["box_offset"])


func _on_dialogue_box_event_triggered(event_name: String) -> void:
	for visitor in _visitors:
		var key: String = visitor["key"]
		if event_name == key + AGREED_EVENT_SUFFIX:
			SandboxState.finished_dialogues[key] = true
		elif event_name == key + LEAVE_EVENT_SUFFIX:
			visitor["area"].is_enabled = false
			visitor["npc"].walk_away()
