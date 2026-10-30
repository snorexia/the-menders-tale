extends Node
## Что песочница помнит между сценами, пока игра запущена (#34, #37).
## Подключён как autoload `SandboxState` в настройках проекта песочницы.
## Не архитектура игры: как хранить состояние, решается на этапе 3.

signal items_changed
signal coins_changed
signal quest_started(title: String)
signal quest_completed(title: String)

const ITEMS_PATH := "res://common/items.json"
const QUESTS_PATH := "res://common/quests.json"
## Сколько слотов в инвентаре.
const SLOT_COUNT := 12

## Персонажи, которые уже подошли и стоят на месте, — по имени.
var arrived_npcs: Dictionary[String, bool] = {}
## Персонажи, которые уже ушли, — по имени.
var left_npcs: Dictionary[String, bool] = {}
## Разговоры, которые уже закончены, — по имени.
var finished_dialogues: Dictionary[String, bool] = {}
## Предметы в инвентаре по слотам: {"id": ..., "quality": ..., "tag": ..., "price": ...}.
var items: Array[Dictionary] = []
var coins: int = 0
## Что где можно сделать — из `items.json`, у каждого рецепта своё место (`station`).
var recipes: Array = []

var _item_infos: Dictionary = {}
var _quest_infos: Dictionary = {}
## Идут и закончены: id заданий.
var _active_quests: Array[String] = []
var _completed_quests: Array[String] = []


func _ready() -> void:
	_load_quests()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	if not data is Dictionary:
		push_warning("SandboxState: не удалось прочитать %s" % ITEMS_PATH)
		return

	_item_infos = data.get("items", {})
	recipes = data.get("recipes", [])
	coins = int(data.get("start_coins", 0))
	for item_id: String in data.get("start_items", []):
		add_item(item_id)


## Рецепты одного места: `anvil`, `smelter`, `workshop` — см. `items.json`.
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
func add_item(item_id: String, quality: String = "", tag: String = "", price: int = 0) -> bool:
	if items.size() >= SLOT_COUNT:
		return false

	items.append({"id": item_id, "quality": quality, "tag": tag, "price": price})
	items_changed.emit()
	return true


## Цена предмета, который заберёт `try_take_item` с теми же условиями. Нет его — 0.
func get_item_price(item_id: String, tag: String = "") -> int:
	var index := _find_item(item_id, tag)
	return items[index]["price"] if index != -1 else 0


## Забрать первый такой предмет; с меткой — именно с этой меткой. Нет его — false.
func try_take_item(item_id: String, tag: String = "") -> bool:
	var index := _find_item(item_id, tag)
	if index == -1:
		return false

	items.remove_at(index)
	items_changed.emit()
	return true


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit()


## Выдать задание. Уже выдано или закончено — ничего не делает.
func start_quest(quest_id: String) -> void:
	if quest_id in _active_quests or quest_id in _completed_quests:
		return

	_active_quests.append(quest_id)
	quest_started.emit(_get_quest_title(quest_id))


## Закончить задание, которое идёт.
func complete_quest(quest_id: String) -> void:
	if not quest_id in _active_quests:
		return

	_active_quests.erase(quest_id)
	_completed_quests.append(quest_id)
	quest_completed.emit(_get_quest_title(quest_id))


## Задания, которые идут: {"title": ..., "steps": [{"text": ..., "is_done": ...}]}.
func get_active_quests() -> Array[Dictionary]:
	var quests: Array[Dictionary] = []
	for quest_id in _active_quests:
		var steps: Array[Dictionary] = []
		for step: Dictionary in _quest_infos[quest_id].get("steps", []):
			var needed_item: String = step.get("needs_item", "")
			var is_done := not needed_item.is_empty() and has_item(needed_item)
			steps.append({"text": step.get("text", ""), "is_done": is_done})

		quests.append({"title": _get_quest_title(quest_id), "steps": steps})

	return quests


func _load_quests() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUESTS_PATH))
	if not data is Dictionary:
		push_warning("SandboxState: не удалось прочитать %s" % QUESTS_PATH)
		return

	_quest_infos = data.get("quests", {})


func _get_quest_title(quest_id: String) -> String:
	return _quest_infos.get(quest_id, {}).get("title", quest_id)


func _find_item(item_id: String, tag: String) -> int:
	return items.find_custom(
		func(item: Dictionary) -> bool:
			return item["id"] == item_id and (tag.is_empty() or item["tag"] == tag)
	)
