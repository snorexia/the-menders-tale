class_name ShopPanel
extends Control
## Лавка (песочница, #56): слева покупаем руду и чертежи, справа продаём лишнее.
## Что и почём — раздел `shop` и `blueprints` в `common/items.json`.

const ROW_SIZE := Vector2(540, 64)
const ROW_FONT_SIZE := 26

@export var buy_format: String = "%s — %d мон."
@export var bought_format: String = "%s — куплен"
@export var bag_full_text: String = "Инвентарь полон"

@onready var _goods: VBoxContainer = %Goods
@onready var _sell_rows: VBoxContainer = %SellRows
@onready var _nothing_label: Label = %NothingLabel
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	hide()
	_close_button.pressed.connect(hide)
	SandboxState.items_changed.connect(_refresh)
	SandboxState.coins_changed.connect(_refresh)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()


## Показать лавку.
func open() -> void:
	show()
	_refresh()


func _refresh() -> void:
	if not visible:
		return

	_clear(_goods)
	_clear(_sell_rows)
	_add_goods()
	_add_blueprints()
	_add_sell_rows()


func _clear(rows: VBoxContainer) -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()


func _add_goods() -> void:
	for good: Dictionary in SandboxState.shop_goods:
		var item_id: String = good["item"]
		var price := int(good["price"])
		var item_name: String = SandboxState.get_item_info(item_id).get("name", item_id)
		var button := _make_row(_goods, buy_format % [item_name, price])
		button.disabled = SandboxState.coins < price
		button.pressed.connect(_on_good_pressed.bind(item_id, price))


func _add_blueprints() -> void:
	for blueprint_id: String in SandboxState.blueprints:
		var blueprint: Dictionary = SandboxState.blueprints[blueprint_id]
		var price := int(blueprint["price"])
		var is_known := SandboxState.is_blueprint_known(blueprint_id)
		var text: String = bought_format % blueprint["name"]
		if not is_known:
			text = buy_format % [blueprint["name"], price]

		var button := _make_row(_goods, text)
		button.disabled = is_known or SandboxState.coins < price
		button.pressed.connect(_on_blueprint_pressed.bind(blueprint_id, price))


func _add_sell_rows() -> void:
	var has_rows := false
	for index in SandboxState.items.size():
		var sell_price := _get_sell_price(index)
		if sell_price <= 0:
			continue

		var item_id: String = SandboxState.items[index]["id"]
		var item_name: String = SandboxState.get_item_info(item_id).get("name", item_id)
		var button := _make_row(_sell_rows, buy_format % [item_name, sell_price])
		button.pressed.connect(_on_sell_pressed.bind(index, sell_price))
		has_rows = true

	_nothing_label.visible = not has_rows


## За сколько лавка купит предмет из слота. Не продаётся — 0.
func _get_sell_price(index: int) -> int:
	var item: Dictionary = SandboxState.items[index]
	if SandboxState.get_item_info(item["id"]).get("not_for_sale", false):
		return 0

	return maxi(roundi(item["price"] * SandboxState.sell_ratio), 0)


func _make_row(rows: VBoxContainer, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = ROW_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	rows.add_child(button)
	return button


func _on_good_pressed(item_id: String, price: int) -> void:
	if SandboxState.add_item(item_id):
		SandboxState.add_coins(-price)
	else:
		SandboxHud.show_message(bag_full_text)


func _on_blueprint_pressed(blueprint_id: String, price: int) -> void:
	SandboxState.known_blueprints.append(blueprint_id)
	SandboxState.add_coins(-price)
	SandboxState.items_changed.emit()


func _on_sell_pressed(index: int, sell_price: int) -> void:
	SandboxState.items.remove_at(index)
	SandboxState.add_coins(sell_price)
	SandboxState.items_changed.emit()
