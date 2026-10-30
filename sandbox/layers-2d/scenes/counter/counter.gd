extends Node2D
## Прилавок (песочница, #37, #54, #56): связывает посетителей, диалог и лавку.
## Посетители приходят сразу и ждут: клик по любому — первый разговор, потом разговор
## о заказе. Заказы можно брать и сдавать в любом порядке. Сдал заказ — посетитель уходит.
## Ушли оба — приходят со следующим кругом заказов из `common/orders.json`.

## События разговора: имя посетителя + окончание.
const AGREED_EVENT_SUFFIX := "_agreed"
const LEAVE_EVENT_SUFFIX := "_leave"

## Где окно реплик относительно посетителя, px. Отрицательный X — окно слева от него.
## Стражник — слева, чтобы не закрыть путника; у путника окно ниже лица стражника.
@export var guard_box_offset: Vector2 = Vector2(-200, -600)
@export var traveller_box_offset: Vector2 = Vector2(-130, -447)
@export var talk_hint_text: String = "Кликни по посетителю, чтобы поговорить"
@export var no_orders_text: String = "Заказов пока нет. Лишнее можно продать в лавке"

var _visitors: Array[Dictionary] = []
var _is_hint_shown: bool = false

@onready var _dialogue_box: DialogueBox = $UI/DialogueBox
@onready var _shop_button: Button = $UI/ShopButton
@onready var _shop: ShopPanel = $UI/ShopPanel


func _ready() -> void:
	_add_visitor("guard", $NpcLayer/Guard, guard_box_offset)
	_add_visitor("traveller", $NpcLayer/Traveller, traveller_box_offset)
	_dialogue_box.event_triggered.connect(_on_dialogue_box_event_triggered)
	_shop_button.pressed.connect(_on_shop_button_pressed)
	# Ушли, пока игрока здесь не было: следующий круг начинается при его возвращении.
	if _are_all_visitors_gone():
		_start_next_round()


func _add_visitor(key: String, npc: WalkingNpc, box_offset: Vector2) -> void:
	var area: ClickableArea = npc.get_node("Body/ClickArea")
	area.is_enabled = false
	var visitor := {"key": key, "npc": npc, "area": area, "box_offset": box_offset}
	_visitors.append(visitor)
	area.clicked.connect(_on_visitor_clicked.bind(visitor))
	npc.arrived.connect(_on_visitor_arrived.bind(visitor))
	npc.left.connect(_on_visitor_left)


func _are_all_visitors_gone() -> bool:
	return _visitors.all(
		func(visitor: Dictionary) -> bool: return SandboxState.left_npcs.get(visitor["key"], false)
	)


func _start_next_round() -> void:
	if not SandboxState.try_start_next_round():
		SandboxHud.show_message(no_orders_text)
		return

	for visitor in _visitors:
		visitor["npc"].come_back()


func _on_visitor_arrived(visitor: Dictionary) -> void:
	visitor["area"].is_enabled = true
	if not _is_hint_shown:
		_is_hint_shown = true
		SandboxHud.show_message(talk_hint_text)


func _on_visitor_left() -> void:
	if _are_all_visitors_gone():
		_start_next_round()


func _on_visitor_clicked(visitor: Dictionary) -> void:
	var npc: WalkingNpc = visitor["npc"]
	if _dialogue_box.visible or _shop.visible or not npc.is_standing():
		return

	var key: String = visitor["key"]
	var is_order_known: bool = SandboxState.finished_dialogues.get(key, false)
	var path := SandboxState.get_order_path(key, "order" if is_order_known else "intro")
	_dialogue_box.start(path, npc, visitor["box_offset"])


func _on_shop_button_pressed() -> void:
	if not _dialogue_box.visible:
		_shop.open()


func _on_dialogue_box_event_triggered(event_name: String) -> void:
	for visitor in _visitors:
		var key: String = visitor["key"]
		if event_name == key + AGREED_EVENT_SUFFIX:
			SandboxState.finished_dialogues[key] = true
		elif event_name == key + LEAVE_EVENT_SUFFIX:
			visitor["area"].is_enabled = false
			visitor["npc"].walk_away()
