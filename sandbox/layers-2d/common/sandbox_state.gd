extends Node
## Что песочница помнит между сценами, пока игра запущена (#34, #37).
## Подключён как autoload `SandboxState` в настройках проекта песочницы.
## Не архитектура игры: как хранить состояние, решается на этапе 3.

signal items_changed
signal coins_changed

const ITEMS_PATH := "res://common/items.json"
## Сколько слотов в инвентаре.
const SLOT_COUNT := 12

## Персонажи, которые уже подошли и стоят на месте, — по имени.
var arrived_npcs: Dictionary[String, bool] = {}
## Персонажи, которые уже ушли, — по имени.
var left_npcs: Dictionary[String, bool] = {}
## Разговоры, которые уже закончены, — по имени.
var finished_dialogues: Dictionary[String, bool] = {}
## Предметы в инвентаре по слотам: {"id": ..., "quality": ...}.
var items: Array[Dictionary] = []
var coins: int = 0
## Что можно сковать — из `items.json`.
var recipes: Array = []

var _item_infos: Dictionary = {}


func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	if not data is Dictionary:
		push_warning("SandboxState: не удалось прочитать %s" % ITEMS_PATH)
		return

	_item_infos = data.get("items", {})
	recipes = data.get("recipes", [])
	coins = int(data.get("start_coins", 0))
	for item_id: String in data.get("start_items", []):
		add_item(item_id)


## Описание предмета из `items.json`: name, icon, description.
func get_item_info(item_id: String) -> Dictionary:
	return _item_infos.get(item_id, {})


func has_item(item_id: String) -> bool:
	return items.any(func(item: Dictionary) -> bool: return item["id"] == item_id)


## Качество первого такого предмета. Нет его или без качества — пусто.
func get_item_quality(item_id: String) -> String:
	var index := items.find_custom(func(item: Dictionary) -> bool: return item["id"] == item_id)
	return items[index]["quality"] if index != -1 else ""


## Положить предмет в свободный слот. Слотов нет — false.
func add_item(item_id: String, quality: String = "") -> bool:
	if items.size() >= SLOT_COUNT:
		return false

	items.append({"id": item_id, "quality": quality})
	items_changed.emit()
	return true


## Забрать первый такой предмет. Нет его — false.
func try_take_item(item_id: String) -> bool:
	var index := items.find_custom(func(item: Dictionary) -> bool: return item["id"] == item_id)
	if index == -1:
		return false

	items.remove_at(index)
	items_changed.emit()
	return true


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit()
