extends Node2D
## Мастерская (песочница, #54): вид сверху на стол. Клик по столу — меню «Что починить?»,
## выбрал вещь — она ложится на стол и начинается подшив. В конце вещь становится целой,
## цена — от звёзд. Материал тратится в конце: ушёл посреди — он остался.

## Рецепты какого места показывать — `station` в `common/items.json`.
const STATION := "workshop"
const PERCENT := 100.0
const STAR_FILLED := "★"
const STAR_EMPTY := "☆"
const STARS_MAX := 3

## Сколько секунд сумка появляется на столе и становится целой.
@export var bag_fade_time: float = 0.4
@export var repair_fade_time: float = 0.9
## Сколько секунд видна надпись про обрыв нитки.
@export var snap_text_time: float = 1.2

@export_group("Тексты")
@export var result_title_format: String = "Готово: %s"
@export var price_format: String = "Цена: %d мон."

var _recipe: Dictionary = {}
var _snap_text_left: float = 0.0

@onready var _table_area: ClickableArea = $TableArea
@onready var _bag: Sprite2D = $Bag
@onready var _bag_repaired: Sprite2D = $Bag/Repaired
@onready var _seam: StitchSeam = $Bag/Seam
@onready var _table_hint: Label = %TableHint
@onready var _repair_panel: Control = %RepairPanel
@onready var _recipes: RecipeMenu = %Recipes
@onready var _sew_ui: Control = %SewUi
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _tension_bar: ProgressBar = %TensionBar
@onready var _stars_label: Label = %StarsLabel
@onready var _snap_label: Label = %SnapLabel
@onready var _result_card: Control = %ResultCard
@onready var _card_title: Label = %CardTitle
@onready var _card_stars: Label = %CardStars
@onready var _price_label: Label = %PriceLabel


func _ready() -> void:
	_bag.hide()
	_seam.hide()
	_repair_panel.hide()
	_sew_ui.hide()
	_result_card.hide()
	_snap_label.modulate.a = 0.0
	_table_area.clicked.connect(_on_table_area_clicked)
	_recipes.recipe_chosen.connect(_on_recipe_chosen)
	_seam.finished.connect(_on_seam_finished)
	_seam.thread_snapped.connect(_on_seam_thread_snapped)


func _process(delta: float) -> void:
	if not _sew_ui.visible:
		return

	_progress_bar.value = _seam.get_progress_ratio() * PERCENT
	_tension_bar.value = _seam.get_tension() * PERCENT
	_stars_label.text = _make_stars_text(_seam.get_stars())
	_snap_text_left = maxf(_snap_text_left - delta, 0.0)
	_snap_label.modulate.a = 1.0 if _snap_text_left > 0.0 else 0.0


func _make_stars_text(stars: int) -> String:
	return STAR_FILLED.repeat(stars) + STAR_EMPTY.repeat(STARS_MAX - stars)


func _on_table_area_clicked() -> void:
	_table_hint.hide()
	_repair_panel.show()
	_recipes.fill(STATION)


func _on_recipe_chosen(recipe: Dictionary) -> void:
	_recipe = recipe
	_table_area.is_enabled = false
	_repair_panel.hide()
	_bag.modulate.a = 0.0
	_bag_repaired.modulate.a = 0.0
	_bag.show()
	var tween := create_tween()
	tween.tween_property(_bag, "modulate:a", 1.0, bag_fade_time)
	await tween.finished
	_sew_ui.show()
	_seam.start()


func _on_seam_thread_snapped() -> void:
	_snap_text_left = snap_text_time


func _on_seam_finished(stars: int) -> void:
	_sew_ui.hide()
	_seam.hide()
	var tween := create_tween()
	tween.tween_property(_bag_repaired, "modulate:a", 1.0, repair_fade_time)
	await tween.finished

	var price: int = _recipe.get("price_by_stars", {}).get(str(stars), 0)
	var repaired_item: String = _recipe.get("gives", "")
	if SandboxState.try_take_item(_recipe.get("needs", "")):
		var grade := SandboxState.get_grade(_recipe, price)
		SandboxState.add_item(repaired_item, _make_stars_text(stars), grade, price)

	var repaired_name: String = SandboxState.get_item_info(repaired_item).get("name", repaired_item)
	_card_title.text = result_title_format % repaired_name.to_lower()
	_card_stars.text = _make_stars_text(stars)
	_price_label.text = price_format % price
	_result_card.show()
