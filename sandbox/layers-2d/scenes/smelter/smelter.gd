extends Node2D
## Крупный план плавильни с мини-игрой «сними шлак» (песочница, #41).
## По расплаву по очереди всплывают куски шлака — кликни, пока не утонули.
## Доля снятых — качество слитка. Руда тратится в конце: ушёл посреди — она осталась.

const PERCENT := 100.0
const FEEDBACK_RISE := 40.0
const FEEDBACK_TIME := 0.6
const FEEDBACK_SIZE := Vector2(200, 44)
const SPAWN_TRIES := 12
## Надпись «Снял!» — выше куска на столько его радиусов.
const FEEDBACK_ABOVE_SLAG := 1.5

## Что плавим и что получаем — id из `common/items.json`.
@export var input_item: String = "ore"
@export var output_item: String = "ingot"
## Сколько кусков шлака всплывёт за плавку.
@export var slag_count: int = 12
## Пауза между кусками, с: случайно от и до.
@export var spawn_interval_min: float = 0.45
@export var spawn_interval_max: float = 0.8
## Пауза перед первым куском, с.
@export var start_delay: float = 1.0
## Не ставить новый кусок ближе этого к предыдущему, px.
@export var min_slag_distance: float = 140.0
## Куски всплывают не дальше этой доли радиуса расплава от центра.
@export_range(0.0, 1.0) var spawn_radius_ratio: float = 0.78

@export_group("Кусок шлака")
@export var slag_radius: float = 46.0
@export var slag_float_time: float = 1.3

@export_group("Качество")
## Пороги доли снятого шлака, от лучшего. Ниже последнего — худшее.
@export var quality_thresholds: PackedFloat32Array = PackedFloat32Array([1.0, 0.75, 0.5])
## Названия качества: на одно больше, чем порогов.
@export var quality_names: PackedStringArray = PackedStringArray(
	["Чистейший металл", "Хороший металл", "С примесями", "Грязный металл"]
)
@export var quality_colors: PackedColorArray = PackedColorArray(
	[
		Color(1.0, 0.8, 0.3),
		Color(0.55, 0.85, 1.0),
		Color(0.85, 0.75, 0.65),
		Color(0.6, 0.55, 0.5),
	]
)

@export_group("Тексты")
@export var feedback_settings: LabelSettings
@export var skim_text: String = "Снял!"
@export var skim_color: Color = Color(1.0, 0.9, 0.5)
@export var item_added_prefix: String = "В инвентаре: "

var _skimmed_count: int = 0
var _resolved_count: int = 0
var _last_slag_position: Vector2 = Vector2.ZERO

@onready var _pool: MoltenPool = $Pool
@onready var _slag: Node2D = $Slag
@onready var _effects: Node2D = $Effects
@onready var _skim_puff: CPUParticles2D = $SkimPuff
@onready var _title: Label = %Title
@onready var _hint: Label = %Hint
@onready var _result_panel: Control = %ResultPanel
@onready var _quality_label: Label = %QualityLabel
@onready var _score_label: Label = %ScoreLabel


func _ready() -> void:
	_result_panel.hide()
	_last_slag_position = _pool.center
	_spawn_slag()


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	get_viewport().set_input_as_handled()
	var click_position := get_global_mouse_position()
	# Сверху — последний всплывший кусок, его и снимаем первым.
	for piece_index in range(_slag.get_child_count() - 1, -1, -1):
		var piece: SlagPiece = _slag.get_child(piece_index)
		if piece.try_skim(click_position):
			_play_skim_effects(piece.position)
			break


func _spawn_slag() -> void:
	await get_tree().create_timer(start_delay).timeout
	for _piece_index in slag_count:
		var piece := SlagPiece.new()
		piece.radius = slag_radius
		piece.float_time = slag_float_time
		piece.position = _pick_slag_position()
		_last_slag_position = piece.position
		piece.resolved.connect(_on_slag_piece_resolved)
		_slag.add_child(piece)
		await get_tree().create_timer(randf_range(spawn_interval_min, spawn_interval_max)).timeout


func _pick_slag_position() -> Vector2:
	var candidate := _random_point_in_pool()
	for _try_index in SPAWN_TRIES:
		if candidate.distance_to(_last_slag_position) >= min_slag_distance:
			break

		candidate = _random_point_in_pool()

	return candidate


func _random_point_in_pool() -> Vector2:
	# sqrt — чтобы точки ложились по кругу равномерно, а не кучей в центре.
	var distance := sqrt(randf()) * _pool.molten_radius * spawn_radius_ratio
	return _pool.center + Vector2.from_angle(randf() * TAU) * distance


func _play_skim_effects(at_position: Vector2) -> void:
	_skim_puff.position = at_position
	_skim_puff.restart()
	var label := Label.new()
	label.text = skim_text
	label.label_settings = feedback_settings.duplicate()
	label.label_settings.font_color = skim_color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = FEEDBACK_SIZE
	label.position = at_position - FEEDBACK_SIZE / 2.0 - Vector2(0, slag_radius * FEEDBACK_ABOVE_SLAG)
	_effects.add_child(label)

	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - FEEDBACK_RISE, FEEDBACK_TIME)
	tween.tween_property(label, "modulate:a", 0.0, FEEDBACK_TIME)
	tween.chain().tween_callback(label.queue_free)


func _show_result() -> void:
	var skim_ratio := float(_skimmed_count) / maxf(slag_count, 1.0)
	var quality_index := _get_quality_index(skim_ratio)
	var percent := roundi(skim_ratio * PERCENT)
	_title.text = "Слиток готов!"
	_hint.hide()
	_quality_label.text = quality_names[quality_index]
	_quality_label.label_settings.font_color = quality_colors[quality_index]
	_score_label.text = "Снято шлака: %d из %d (%d %%)" % [_skimmed_count, slag_count, percent]
	_result_panel.show()
	_smelt(quality_names[quality_index])


func _get_quality_index(skim_ratio: float) -> int:
	var quality_index := quality_thresholds.size()
	for index in quality_thresholds.size():
		if skim_ratio >= quality_thresholds[index]:
			quality_index = index
			break

	return quality_index


func _smelt(quality: String) -> void:
	if not SandboxState.try_take_item(input_item):
		return

	SandboxState.add_item(output_item, quality)
	var output_name: String = SandboxState.get_item_info(output_item).get("name", output_item)
	SandboxHud.show_message(item_added_prefix + output_name.to_lower())


func _on_slag_piece_resolved(is_skimmed: bool) -> void:
	_resolved_count += 1
	if is_skimmed:
		_skimmed_count += 1
	if _resolved_count == slag_count:
		_show_result()
