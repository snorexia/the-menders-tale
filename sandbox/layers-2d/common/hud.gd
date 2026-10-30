extends CanvasLayer
## Интерфейс поверх всех сцен песочницы (#37): монеты и задания справа сверху, сундук
## слева снизу открывает инвентарь (или TAB), всплывающие надписи по центру.
## Подключён как autoload `SandboxHud`. Не архитектура игры.

const SLOT_SIZE := Vector2(104, 104)
const ICON_MARGIN := 14
const MESSAGE_SHOW_TIME := 1.6
const MESSAGE_FADE_TIME := 0.6

## Вид пустого и занятого слота.
@export var slot_style: StyleBox
## Как подписать качество в подсказке.
@export var quality_prefix: String = "Качество: "
## Как подписать цену в подсказке.
@export var price_format: String = "Цена: %d мон."

@export_group("Задания")
@export var quest_title_settings: LabelSettings
@export var quest_step_settings: LabelSettings
@export var quest_started_prefix: String = "Новое задание: "
@export var quest_completed_prefix: String = "Задание выполнено: "
@export var step_pending_prefix: String = "•  "
@export var step_done_prefix: String = "✓  "
@export var step_done_color: Color = Color(0.6, 0.95, 0.6)

var _message_tween: Tween

@onready var _coin_label: Label = %CoinLabel
@onready var _inventory_button: TextureButton = %InventoryButton
@onready var _inventory_panel: Control = %InventoryPanel
@onready var _slots: GridContainer = %Slots
@onready var _message_label: Label = %MessageLabel
@onready var _quest_list: VBoxContainer = %QuestList


func _ready() -> void:
	_inventory_panel.hide()
	_message_label.modulate.a = 0.0
	_inventory_button.pressed.connect(_toggle_inventory)
	SandboxState.items_changed.connect(_update_slots)
	SandboxState.coins_changed.connect(_update_coins)
	SandboxState.items_changed.connect(_update_quests)
	SandboxState.quest_started.connect(_on_quest_started)
	SandboxState.quest_completed.connect(_on_quest_completed)
	_create_slots()
	_update_slots()
	_update_coins()


func _input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_TAB:
		return

	# Иначе TAB переключает фокус между кнопками сцены.
	get_viewport().set_input_as_handled()
	_toggle_inventory()


## Всплывающая надпись по центру экрана, сама гаснет.
func show_message(text: String) -> void:
	_message_label.text = text
	_message_label.modulate.a = 1.0
	if _message_tween != null:
		_message_tween.kill()

	_message_tween = create_tween()
	_message_tween.tween_interval(MESSAGE_SHOW_TIME)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, MESSAGE_FADE_TIME)


func _toggle_inventory() -> void:
	_inventory_panel.visible = not _inventory_panel.visible


func _create_slots() -> void:
	for _slot_index in SandboxState.SLOT_COUNT:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.add_theme_stylebox_override("panel", slot_style)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side: String in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, ICON_MARGIN)

		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Пиксельные иконки увеличиваем без размытия.
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		margin.add_child(icon)
		slot.add_child(margin)
		_slots.add_child(slot)


func _update_slots() -> void:
	for slot_index in _slots.get_child_count():
		var slot: PanelContainer = _slots.get_child(slot_index)
		var icon: TextureRect = slot.get_child(0).get_child(0)
		var item: Dictionary = {}
		if slot_index < SandboxState.items.size():
			item = SandboxState.items[slot_index]

		_fill_slot(slot, icon, item)


func _fill_slot(slot: Control, icon: TextureRect, item: Dictionary) -> void:
	var info := SandboxState.get_item_info(item.get("id", ""))
	icon.texture = load(info["icon"]) if info.has("icon") else null
	slot.tooltip_text = _get_tooltip(info, item.get("quality", ""), item.get("price", 0))


func _get_tooltip(info: Dictionary, quality: String, price: int) -> String:
	var lines: PackedStringArray = []
	if info.has("name"):
		lines.append(info["name"])
	if not quality.is_empty():
		lines.append(quality_prefix + quality)
	if price > 0:
		lines.append(price_format % price)
	if info.has("description"):
		lines.append(info["description"])

	return "\n".join(lines)


func _update_coins() -> void:
	_coin_label.text = str(SandboxState.coins)


func _update_quests() -> void:
	for child in _quest_list.get_children():
		child.queue_free()

	for quest: Dictionary in SandboxState.get_active_quests():
		_quest_list.add_child(_make_quest_label(quest["title"], quest_title_settings))
		for step: Dictionary in quest["steps"]:
			var is_done: bool = step["is_done"]
			var prefix := step_done_prefix if is_done else step_pending_prefix
			var label := _make_quest_label(prefix + step["text"], quest_step_settings)
			label.modulate = step_done_color if is_done else Color.WHITE
			_quest_list.add_child(label)


func _make_quest_label(text: String, settings: LabelSettings) -> Label:
	var label := Label.new()
	label.text = text
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _on_quest_started(title: String) -> void:
	show_message(quest_started_prefix + title)
	_update_quests()


func _on_quest_completed(title: String) -> void:
	show_message(quest_completed_prefix + title)
	_update_quests()
