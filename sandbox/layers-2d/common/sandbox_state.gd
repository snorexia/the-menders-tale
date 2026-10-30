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
## Предметы в инвентаре по слотам: {"id": ..., "quality": ..., "tag": ...}.
var items: Array[Dictionary] = []
var coins: int = 0
## Что где можно сделать — из `items.json`, у каждого рецепта своё место (`station`).
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


## Рецепты одного места: `anvil`, `smelter` — см. `items.json`.
func get_recipes(station: String) -> Array:
	return recipes.filter(func(recipe: Dictionary) -> bool: return recipe.get("station") == station)


## Описание предмета из `items.json`: name, icon, description.
func get_item_info(item_id: String) -> Dictionary:
	return _item_infos.get(item_id, {})


func has_item(item_id: String) -> bool:
	return items.any(func(item: Dictionary) -> bool: return item["id"] == item_id)


## Сколько таких предметов в инвентаре.
func count_item(item_id: String) -> int:
	return items.filter(func(item: Dictionary) -> bool: return item["id"] == item_id).size()


## Есть ли такой предмет с такой меткой, например меч с отличной заточкой.
func has_tagged_item(item_id: String, tag: String) -> bool:
	return items.any(
		func(item: Dictionary) -> bool: return item["id"] == item_id and item["tag"] == tag
	)


## Положить предмет в свободный слот. Слотов нет — false.
func add_item(item_id: String, quality: String = "", tag: String = "") -> bool:
	if items.size() >= SLOT_COUNT:
		return false

	items.append({"id": item_id, "quality": quality, "tag": tag})
	items_changed.emit()
	return true


## Забрать первый такой предмет; с меткой — именно с этой меткой. Нет его — false.
func try_take_item(item_id: String, tag: String = "") -> bool:
	var index := items.find_custom(
		func(item: Dictionary) -> bool:
			return item["id"] == item_id and (tag.is_empty() or item["tag"] == tag)
	)
	if index == -1:
		return false

	items.remove_at(index)
	items_changed.emit()
	return true


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit()
