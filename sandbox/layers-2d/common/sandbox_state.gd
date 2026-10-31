extends Node
## Что песочница помнит между сценами, пока игра запущена (#34, #37, #56).
## Подключён как autoload `SandboxState` в настройках проекта песочницы.
## Не архитектура игры: как хранить состояние, решается на этапе 3.

signal items_changed
signal coins_changed
signal quest_started(title: String)
signal quest_completed(title: String)

const ITEMS_PATH := "res://common/items.json"
const QUESTS_PATH := "res://common/quests.json"
const ORDERS_PATH := "res://common/orders.json"
## Итоги вещи, от худшего к лучшему.
const GRADES: Array[String] = ["bad", "normal", "good"]
## Сколько слотов в инвентаре.
const SLOT_COUNT := 24

## Персонажи, которые уже подошли и стоят на месте, — по имени.
var arrived_npcs: Dictionary[String, bool] = {}
## Персонажи, которые уже ушли, — по имени.
var left_npcs: Dictionary[String, bool] = {}
## Разговоры, которые уже закончены, — по имени.
var finished_dialogues: Dictionary[String, bool] = {}
## Предметы в инвентаре по слотам: {"id": ..., "quality": ..., "grade": ..., "price": ...}.
var items: Array[Dictionary] = []
var coins: int = 0
## Что где можно сделать — из `items.json`, у каждого рецепта своё место (`station`).
var recipes: Array = []
## Что продаёт лавка и какие чертежи — из `items.json`.
var shop_goods: Array = []
var blueprints: Dictionary = {}
var known_blueprints: Array[String] = []
## Какую долю цены вещи платит лавка.
var sell_ratio: float = 0.0

var _item_infos: Dictionary = {}
## Какой вариант вещи выпал в прошлый раз — по id вещи.
var _last_variants: Dictionary[String, int] = {}
var _grade_names: Dictionary = {}
var _material_bonus: Dictionary = {}
var _order_rounds: Array = []
var _order_round: int = 0
var _quest_infos: Dictionary = {}
## Идут и закончены: id заданий.
var _active_quests: Array[String] = []
var _completed_quests: Array[String] = []


func _ready() -> void:
	_load_quests()
	_load_orders()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	if not data is Dictionary:
		push_warning("SandboxState: не удалось прочитать %s" % ITEMS_PATH)
		return

	_item_infos = data.get("items", {})
	recipes = data.get("recipes", [])
	blueprints = data.get("blueprints", {})
	_grade_names = data.get("grade_names", {})
	_material_bonus = data.get("material_bonus", {})
	var shop: Dictionary = data.get("shop", {})
	shop_goods = shop.get("goods", [])
	sell_ratio = shop.get("sell_ratio", 0.0)
	coins = int(data.get("start_coins", 0))
	for item_id: String in data.get("start_items", []):
		add_item(item_id)


## Рецепты одного места: `anvil`, `smelter`, `workshop` — см. `items.json`. Без чертежа не видны.
func get_recipes(station: String) -> Array:
	return recipes.filter(
		func(recipe: Dictionary) -> bool:
			var blueprint: String = recipe.get("blueprint", "")
			var is_available := blueprint.is_empty() or is_blueprint_known(blueprint)
			return recipe.get("station") == station and is_available
	)


## Случайный вариант вещи: не тот же, что в прошлый раз. Вариантов нет — пусто.
func pick_variant(item_id: String, variants: Array) -> Dictionary:
	if variants.is_empty():
		return {}

	var index := randi() % variants.size()
	if variants.size() > 1 and index == _last_variants.get(item_id, -1):
		index = (index + 1 + randi() % (variants.size() - 1)) % variants.size()

	_last_variants[item_id] = index
	return variants[index]


## Описание предмета из `items.json`: name, icon, description.
func get_item_info(item_id: String) -> Dictionary:
	return _item_infos.get(item_id, {})


## Есть ли такой предмет; с `min_grade` — не хуже этого итога.
func has_item(item_id: String, min_grade: String = "") -> bool:
	return _find_item(item_id, min_grade) != -1


## Сколько таких предметов в инвентаре.
func count_item(item_id: String) -> int:
	return items.filter(func(item: Dictionary) -> bool: return item["id"] == item_id).size()


## Качество предмета, который заберёт `try_take_item`. Нет его или без качества — пусто.
func get_item_quality(item_id: String) -> String:
	var index := _find_item(item_id, "")
	return items[index]["quality"] if index != -1 else ""


## Итог предмета, который заберёт `try_take_item` с теми же условиями. Нет его — пусто.
func get_item_grade(item_id: String, min_grade: String = "") -> String:
	var index := _find_item(item_id, min_grade)
	return items[index]["grade"] if index != -1 else ""


## Итог вещи по цене: границы — `grade_from_price` у рецепта.
func get_grade(recipe: Dictionary, price: int) -> String:
	var limits: Dictionary = recipe.get("grade_from_price", {})
	var grade := "bad"
	if price >= int(limits.get("good", INF)):
		grade = "good"
	elif price >= int(limits.get("normal", INF)):
		grade = "normal"

	return grade


func get_grade_name(grade: String) -> String:
	return _grade_names.get(grade, grade)


## Сколько монет прибавляет к цене качество материала.
func get_material_bonus(material: String) -> int:
	return int(_material_bonus.get(material, 0))


## Положить предмет в свободный слот. Слотов нет — false.
func add_item(item_id: String, quality: String = "", grade: String = "", price: int = 0) -> bool:
	if items.size() >= SLOT_COUNT:
		return false

	items.append({"id": item_id, "quality": quality, "grade": grade, "price": price})
	items_changed.emit()
	return true


## Цена предмета, который заберёт `try_take_item` с теми же условиями. Нет его — 0.
func get_item_price(item_id: String, min_grade: String = "") -> int:
	var index := _find_item(item_id, min_grade)
	return items[index]["price"] if index != -1 else 0


## Забрать самый дорогой такой предмет не хуже `min_grade`. Нет его — false.
func try_take_item(item_id: String, min_grade: String = "") -> bool:
	var index := _find_item(item_id, min_grade)
	if index == -1:
		return false

	items.remove_at(index)
	items_changed.emit()
	return true


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit()


func is_blueprint_known(blueprint_id: String) -> bool:
	return blueprint_id in known_blueprints


## Путь к разговору посетителя в текущем круге: `intro` или `order`.
func get_order_path(visitor_key: String, kind: String) -> String:
	return _order_rounds[_order_round][visitor_key][kind]


## Следующий круг заказов: посетители забывают, что подходили и уходили. Кругов нет — false.
func try_start_next_round() -> bool:
	if _order_round + 1 >= _order_rounds.size():
		return false

	_order_round += 1
	arrived_npcs.clear()
	left_npcs.clear()
	finished_dialogues.clear()
	return true


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
			steps.append({"text": step.get("text", ""), "is_done": _is_step_done(step)})

		quests.append({"title": _get_quest_title(quest_id), "steps": steps})

	return quests


func _is_step_done(step: Dictionary) -> bool:
	if step.has("needs_blueprint"):
		return is_blueprint_known(step["needs_blueprint"])

	var needed_item: String = step.get("needs_item", "")
	return not needed_item.is_empty() and has_item(needed_item, step.get("needs_grade", ""))


func _load_orders() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORDERS_PATH))
	if not data is Dictionary:
		push_warning("SandboxState: не удалось прочитать %s" % ORDERS_PATH)
		return

	_order_rounds = data.get("rounds", [])


func _load_quests() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUESTS_PATH))
	if not data is Dictionary:
		push_warning("SandboxState: не удалось прочитать %s" % QUESTS_PATH)
		return

	_quest_infos = data.get("quests", {})


func _get_quest_title(quest_id: String) -> String:
	return _quest_infos.get(quest_id, {}).get("title", quest_id)


## Самый дорогой такой предмет не хуже `min_grade`; при равной цене — первый. Нет — -1.
func _find_item(item_id: String, min_grade: String) -> int:
	var best := -1
	for index in items.size():
		var item: Dictionary = items[index]
		if item["id"] != item_id or GRADES.find(item["grade"]) < GRADES.find(min_grade):
			continue
		if best == -1 or item["price"] > items[best]["price"]:
			best = index

	return best
