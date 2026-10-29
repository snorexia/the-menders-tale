extends Node2D
## Крупный план точильного колеса с мини-игрой «педаль и скорость» (песочница, #42).
## Клик или пробел жмёт педаль — колесо разгоняется, без кликов замедляется.
## Скорость в зелёной зоне — меч точится; выше зоны клинок греется. Перегрел —
## меч остался незаточенным, можно ещё раз. Заточил — незаточенный меч становится
## обычным с тем же качеством ковки.

const PERCENT := 100.0
const HINT_FADE_TIME := 1.0

## Что точим и что получаем — id из `common/items.json`.
@export var input_item: String = "sword_blunt"
@export var output_item: String = "sword"
## Насколько разгоняет одно нажатие педали: доля полной скорости.
@export var pedal_impulse: float = 0.12
## Насколько колесо замедляется само: доля полной скорости в секунду.
@export var friction: float = 0.28
## Зелёная зона скорости: от и до, доли шкалы.
@export_range(0.0, 1.0) var good_from: float = 0.45
@export_range(0.0, 1.0) var good_to: float = 0.75
## Сколько секунд в зелёной зоне нужно, чтобы заточить.
@export var sharpen_time: float = 5.0
## Сколько секунд выше зоны выдерживает клинок.
@export var overheat_limit: float = 1.5
## Как быстро клинок остывает, когда скорость не выше зоны: доля от нагрева.
@export var cool_rate: float = 0.5
## Оборотов колеса в секунду на полной скорости — только для вида.
@export var max_turns_per_second: float = 2.5

@export_group("Вид")
## Цвет клинка при полном перегреве.
@export var overheat_color: Color = Color(1.0, 0.45, 0.3)
@export var speed_fill_color: Color = Color(0.55, 0.8, 1.0)
@export var too_fast_fill_color: Color = Color(1.0, 0.4, 0.25)

@export_group("Тексты")
@export var too_fast_text: String = "Слишком быстро — клинок греется!"
@export var sharpened_text: String = "Меч заточен"
@export var overheated_text: String = "Перегрел — меч не заточен"
@export var sharpened_color: Color = Color(0.55, 0.85, 1.0)
@export var overheated_color: Color = Color(1.0, 0.5, 0.35)
@export var item_added_prefix: String = "В инвентаре: "

var _speed: float = 0.0
var _sharpness: float = 0.0
var _overheat: float = 0.0
var _is_finished: bool = false

@onready var _wheel: GrinderWheel = $Wheel
@onready var _sword: Sprite2D = $Sword
@onready var _sparks: CPUParticles2D = $Sparks
@onready var _speed_bar: ProgressBar = %SpeedBar
@onready var _good_zone: Control = %GoodZone
@onready var _sharpness_bar: ProgressBar = %SharpnessBar
@onready var _status_label: Label = %StatusLabel
@onready var _result_panel: Control = %ResultPanel
@onready var _quality_label: Label = %QualityLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _retry_button: Button = %RetryButton


func _ready() -> void:
	_retry_button.pressed.connect(_start_sharpening)
	_good_zone.anchor_left = good_from
	_good_zone.anchor_right = good_to
	# Заливку шкалы перекрашиваем по скорости — у сцены своя копия стиля.
	var fill_style: StyleBox = _speed_bar.get_theme_stylebox("fill").duplicate()
	_speed_bar.add_theme_stylebox_override("fill", fill_style)
	_start_sharpening()


func _process(delta: float) -> void:
	_speed = maxf(_speed - friction * delta, 0.0)
	if not _is_finished:
		_grind(delta)

	_update_visuals()


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	var key_event := event as InputEventKey
	var is_click := (
		mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	)
	var is_space := (
		key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_SPACE
	)
	if not is_click and not is_space:
		return

	get_viewport().set_input_as_handled()
	if not _is_finished:
		_speed = minf(_speed + pedal_impulse, 1.0)


func _start_sharpening() -> void:
	_speed = 0.0
	_sharpness = 0.0
	_overheat = 0.0
	_is_finished = false
	_result_panel.hide()
	_status_label.modulate.a = 0.0


func _grind(delta: float) -> void:
	if _speed > good_to:
		_overheat += delta
		_status_label.text = too_fast_text
		_status_label.modulate.a = 1.0
	else:
		_overheat = maxf(_overheat - cool_rate * delta, 0.0)
		_status_label.modulate.a = maxf(_status_label.modulate.a - delta / HINT_FADE_TIME, 0.0)

	if _speed >= good_from and _speed <= good_to:
		_sharpness = minf(_sharpness + delta / sharpen_time, 1.0)

	if _overheat >= overheat_limit:
		_finish(false)
	elif _sharpness >= 1.0:
		_finish(true)


func _finish(is_sharpened: bool) -> void:
	_is_finished = true
	_status_label.modulate.a = 0.0
	var percent := roundi(_sharpness * PERCENT)
	_quality_label.text = sharpened_text if is_sharpened else overheated_text
	_quality_label.label_settings.font_color = sharpened_color if is_sharpened else overheated_color
	_score_label.text = "Заточка: %d %%" % percent
	_retry_button.visible = not is_sharpened
	_result_panel.show()
	if is_sharpened:
		_sharpen_item()


## Меч остаётся того же качества, что выковали.
func _sharpen_item() -> void:
	var quality := SandboxState.get_item_quality(input_item)
	if not SandboxState.try_take_item(input_item):
		return

	SandboxState.add_item(output_item, quality)
	var output_name: String = SandboxState.get_item_info(output_item).get("name", output_item)
	SandboxHud.show_message(item_added_prefix + output_name.to_lower())


func _update_visuals() -> void:
	_wheel.spin_speed = _speed * max_turns_per_second
	_sparks.emitting = _speed >= good_from and not _is_finished
	_sword.modulate = Color.WHITE.lerp(overheat_color, _overheat / overheat_limit)
	_speed_bar.value = _speed * PERCENT
	_sharpness_bar.value = _sharpness * PERCENT
	var fill_style := _speed_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style != null:
		fill_style.bg_color = too_fast_fill_color if _speed > good_to else speed_fill_color
