extends Node2D
## Мастерская (песочница, #54, #60): вид сверху на стол. Клик по столу — меню «Что починить?»,
## выбрал вещь — выпадает её случайный вариант и начинается мини-игра рецепта (`game`).
## Цена — от звёзд и сложности варианта. Материал тратится в конце: ушёл посреди — он остался.
## У каждой мини-игры одно и то же: `start(variant)`, `get_progress_ratio()`, `get_tension()`,
## `get_stars()`, `get_price_bonus()`, сигналы `finished(stars)` и `mistake_made`.

## Рецепты какого места показывать — `station` в `common/items.json`.
const STATION := "workshop"
const STITCH_GAME := "stitch"
const PERCENT := 100.0
const STAR_FILLED := "★"
const STAR_EMPTY := "☆"
const STARS_MAX := 3

## Сколько секунд сумка появляется на столе и разрыв исчезает.
@export var bag_fade_time: float = 0.4
@export var repair_fade_time: float = 0.9
## Сколько секунд видна надпись про ошибку.
@export var mistake_text_time: float = 1.2

@export_group("Тексты")
@export var result_title_format: String = "Готово: %s"
@export var price_format: String = "Цена: %d мон."

var _recipe: Dictionary = {}
var _mistake_text_left: float = 0.0
## Мини-игры верстака: название из рецепта — узел. Идёт — `_game`.
var _games: Dictionary[String, Node] = {}
var _game: Node

@onready var _table_area: ClickableArea = $TableArea
@onready var _bag: Sprite2D = $Bag
@onready var _seam: StitchSeam = $Bag/Seam
@onready var _shards_game: ShardsGame = $ShardsGame
@onready var _rivets_game: RivetsGame = $RivetsGame
@onready var _scales_game: ScalesGame = $ScalesGame
@onready var _chain_game: ChainGame = $ChainGame
@onready var _rune_game: RuneGame = $RuneGame
@onready var _table_hint: Label = %TableHint
@onready var _repair_panel: Control = %RepairPanel
@onready var _recipes: RecipeMenu = %Recipes
@onready var _sew_ui: Control = %SewUi
@onready var _progress_label: Label = %ProgressLabel
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _tension_label: Label = %TensionLabel
@onready var _tension_bar: ProgressBar = %TensionBar
@onready var _stars_label: Label = %StarsLabel
@onready var _mistake_label: Label = %MistakeLabel
@onready var _game_hint: Label = %GameHint
@onready var _result_card: Control = %ResultCard
@onready var _card_title: Label = %CardTitle
@onready var _card_stars: Label = %CardStars
@onready var _price_label: Label = %PriceLabel
@onready var _again_button: Button = %AgainButton


func _ready() -> void:
	_bag.hide()
	_seam.hide()
	_repair_panel.hide()
	_sew_ui.hide()
	_result_card.hide()
	_mistake_label.modulate.a = 0.0
	_table_area.clicked.connect(_on_table_area_clicked)
	_recipes.recipe_chosen.connect(_on_recipe_chosen)
	_again_button.pressed.connect(get_tree().reload_current_scene)
	_games = {
		STITCH_GAME: _seam,
		"shards": _shards_game,
		"rivets": _rivets_game,
		"scales": _scales_game,
		"chain": _chain_game,
		"runes": _rune_game,
	}
	for game: Node in _games.values():
		game.finished.connect(_on_game_finished)
		game.mistake_made.connect(_on_game_mistake_made)


func _process(delta: float) -> void:
	if not _sew_ui.visible:
		return

	_progress_bar.value = _game.get_progress_ratio() * PERCENT
	_tension_bar.value = _game.get_tension() * PERCENT
	_stars_label.text = _make_stars_text(_game.get_stars())
	_mistake_text_left = maxf(_mistake_text_left - delta, 0.0)
	_mistake_label.modulate.a = 1.0 if _mistake_text_left > 0.0 else 0.0


func _make_stars_text(stars: int) -> String:
	return STAR_FILLED.repeat(stars) + STAR_EMPTY.repeat(STARS_MAX - stars)


func _show_game_ui(variant: Dictionary) -> void:
	var tension_text: String = _recipe.get("tension_label", "")
	_game_hint.text = variant.get("hint", _recipe.get("hint", ""))
	_progress_label.text = _recipe.get("progress_label", "")
	_tension_label.text = tension_text
	_tension_label.visible = not tension_text.is_empty()
	_tension_bar.visible = not tension_text.is_empty()
	_mistake_label.text = _recipe.get("mistake_text", "")
	_sew_ui.show()


func _on_table_area_clicked() -> void:
	_table_hint.hide()
	_repair_panel.show()
	_recipes.fill(STATION)


func _on_recipe_chosen(recipe: Dictionary) -> void:
	_recipe = recipe
	_table_area.is_enabled = false
	_repair_panel.hide()
	var game_name: String = recipe.get("game", STITCH_GAME)
	_game = _games[game_name]
	if game_name == STITCH_GAME:
		_bag.modulate.a = 0.0
		_bag.show()
		var tween := create_tween()
		tween.tween_property(_bag, "modulate:a", 1.0, bag_fade_time)
		await tween.finished

	var variants: Array = recipe.get("variants", [])
	var variant := SandboxState.pick_variant(recipe.get("gives", ""), variants)
	_show_game_ui(variant)
	_game.start(variant)


func _on_game_mistake_made() -> void:
	_mistake_text_left = mistake_text_time


func _on_game_finished(stars: int) -> void:
	_sew_ui.hide()
	if _game == _seam:
		var tween := create_tween()
		tween.tween_property(_seam, "modulate:a", 0.0, repair_fade_time)
		await tween.finished

	var price_by_stars: Dictionary = _recipe.get("price_by_stars", {})
	var price: int = price_by_stars.get(str(stars), 0) + _game.get_price_bonus()
	var repaired_item: String = _recipe.get("gives", "")
	var needed_item: String = _recipe.get("needs", "")
	if SandboxState.try_take_item(needed_item):
		var grade := SandboxState.get_grade(_recipe, price)
		SandboxState.add_item(repaired_item, _make_stars_text(stars), grade, price)

	var repaired_name: String = SandboxState.get_item_info(repaired_item).get("name", repaired_item)
	_card_title.text = result_title_format % repaired_name.to_lower()
	_card_stars.text = _make_stars_text(stars)
	_price_label.text = price_format % price
	_again_button.visible = not SandboxState.get_recipes(STATION).filter(_is_recipe_ready).is_empty()
	_result_card.show()


func _is_recipe_ready(recipe: Dictionary) -> bool:
	return SandboxState.has_item(recipe.get("needs", ""))
