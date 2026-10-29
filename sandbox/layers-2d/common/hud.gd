extends CanvasLayer
## Интерфейс поверх всех сцен песочницы (#37): монеты справа сверху, сундук слева
## снизу открывает инвентарь (или TAB), всплывающие надписи по центру.
## Подключён как autoload `SandboxHud`. Не архитектура игры.

const SLOT_SIZE := Vector2(104, 104)
const ICON_MARGIN := 14
const MESSAGE_SHOW_TIME := 1.6
const MESSAGE_FADE_TIME := 0.6

## Вид пустого и занятого слота.
@export var slot_style: StyleBox
## Как подписать качество в подсказке.
@export var quality_prefix: String = "Качество: "

var _message_tween: Tween

@onready var _coin_label: Label = %CoinLabel
@onready var _inventory_button: TextureButton = %InventoryButton
@onready var _inventory_panel: Control = %InventoryPanel
@onready var _slots: GridContainer = %Slots
@onready var _message_label: Label = %MessageLabel


func _ready() -> void:
	_inventory_panel.hide()
	_message_label.modulate.a = 0.0
	_inventory_button.pressed.connect(_toggle_inventory)
	SandboxState.items_changed.connect(_update_slots)
	SandboxState.coins_changed.connect(_update_coins)
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
	icon.modulate = Color.from_string(info.get("tint", ""), Color.WHITE)
	slot.tooltip_text = _get_tooltip(info, item.get("quality", ""))


func _get_tooltip(info: Dictionary, quality: String) -> String:
	var lines: PackedStringArray = []
	if info.has("name"):
		lines.append(info["name"])
	if not quality.is_empty():
		lines.append(quality_prefix + quality)
	if info.has("description"):
		lines.append(info["description"])

	return "\n".join(lines)


func _update_coins() -> void:
	_coin_label.text = str(SandboxState.coins)
