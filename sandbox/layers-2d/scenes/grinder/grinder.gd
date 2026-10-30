extends Node2D
## Точильное колесо в сцене создания, мини-игра «педаль и скорость» (песочница, #42, #51).
## Клик или пробел жмёт педаль — колесо разгоняется, без кликов замедляется.
## Скорость в зелёной зоне — меч точится; выше зоны клинок греется. Заточил — оценка:
## почти не грел — отлично, иначе хорошо. Перегрел — «Ещё раз» или оставить среднюю.
## Сначала выбор на самом колесе: «Сам» — мини-игра, «Быстро» — сразу средняя заточка.

signal sharpened(rating: String)

const PERCENT := 100.0
const HINT_FADE_TIME := 1.0

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
## «Отлично», если нагрев не поднимался выше этой доли от предела.
@export_range(0.0, 1.0) var excellent_heat_ratio: float = 0.35
## Оборотов колеса в секунду на полной скорости — только для вида.
@export var max_turns_per_second: float = 2.5

@export_group("Вид")
## Свечение клинка при полном перегреве: накладывается сверху, прозрачность — сила.
@export var overheat_glow: Color = Color(1.0, 0.35, 0.1, 0.75)
@export var speed_fill_color: Color = Color(0.55, 0.8, 1.0)
@export var too_fast_fill_color: Color = Color(1.0, 0.4, 0.25)

@export_group("Тексты")
@export var too_fast_text: String = "Слишком быстро — клинок греется!"
@export var overheated_text: String = "Перегрел — меч не заточен"
@export var excellent_text: String = "отлично"
@export var good_text: String = "хорошо"
## Оценка без мини-игры и после отказа от новой попытки.
@export var medium_text: String = "средне"

## Заточка вышла отличной — читает сцена создания после `sharpened`.
var is_excellent: bool = false

var _speed: float = 0.0
var _sharpness: float = 0.0
var _overheat: float = 0.0
var _peak_overheat: float = 0.0
var _is_running: bool = false

@onready var _vignette_layer: CanvasLayer = $VignetteLayer
@onready var _ui: CanvasLayer = $UI
@onready var _wheel_spin: WheelSpin = $Background/WheelSpin
@onready var _blade_glow: Polygon2D = $Background/BladeGlow
@onready var _sparks: CPUParticles2D = $Background/Sparks
@onready var _speed_bar: ProgressBar = %SpeedBar
@onready var _good_zone: Control = %GoodZone
@onready var _sharpness_bar: ProgressBar = %SharpnessBar
@onready var _status_label: Label = %StatusLabel
@onready var _choice_panel: Control = %ChoicePanel
@onready var _by_hand_button: Button = %ByHandButton
@onready var _fast_button: Button = %FastButton
@onready var _result_panel: Control = %ResultPanel
@onready var _quality_label: Label = %QualityLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _retry_button: Button = %RetryButton
@onready var _medium_button: Button = %MediumButton


func _ready() -> void:
	_retry_button.pressed.connect(_reset)
	_medium_button.pressed.connect(_finish_with_medium)
	_fast_button.pressed.connect(_finish_with_medium)
	_by_hand_button.pressed.connect(_reset)
	_good_zone.anchor_left = good_from
	_good_zone.anchor_right = good_to
	# Заливку шкалы перекрашиваем по скорости — у сцены своя копия стиля.
	var fill_style: StyleBox = _speed_bar.get_theme_stylebox("fill").duplicate()
	_speed_bar.add_theme_stylebox_override("fill", fill_style)
	set_ui_visible(false)


func _process(delta: float) -> void:
	_speed = maxf(_speed - friction * delta, 0.0)
	if _is_running:
		_grind(delta)

	_update_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_running:
		return

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
	_speed = minf(_speed + pedal_impulse, 1.0)


## Предложить выбор «Сам» или «Быстро»; по окончании — сигнал `sharpened`.
func start() -> void:
	is_excellent = false
	_result_panel.hide()
	_choice_panel.show()
	set_ui_visible(true)


## Показать или скрыть интерфейс колеса: слои экрана не подчиняются видимости узла.
func set_ui_visible(value: bool) -> void:
	_vignette_layer.visible = value
	_ui.visible = value


func _reset() -> void:
	_speed = 0.0
	_sharpness = 0.0
	_overheat = 0.0
	_peak_overheat = 0.0
	_is_running = true
	_choice_panel.hide()
	_result_panel.hide()
	_status_label.modulate.a = 0.0


func _grind(delta: float) -> void:
	if _speed > good_to:
		_overheat += delta
		_peak_overheat = maxf(_peak_overheat, _overheat)
		_status_label.text = too_fast_text
		_status_label.modulate.a = 1.0
	else:
		_overheat = maxf(_overheat - cool_rate * delta, 0.0)
		_status_label.modulate.a = maxf(_status_label.modulate.a - delta / HINT_FADE_TIME, 0.0)

	if _speed >= good_from and _speed <= good_to:
		_sharpness = minf(_sharpness + delta / sharpen_time, 1.0)

	if _overheat >= overheat_limit:
		_fail()
	elif _sharpness >= 1.0:
		_succeed()


func _succeed() -> void:
	_is_running = false
	is_excellent = _peak_overheat <= overheat_limit * excellent_heat_ratio
	sharpened.emit(excellent_text if is_excellent else good_text)


func _fail() -> void:
	_is_running = false
	_status_label.modulate.a = 0.0
	var percent := roundi(_sharpness * PERCENT)
	_quality_label.text = overheated_text
	_score_label.text = "Заточка: %d %%" % percent
	_result_panel.show()


func _update_visuals() -> void:
	_wheel_spin.spin_speed = _speed * max_turns_per_second
	_sparks.emitting = _speed >= good_from and _is_running
	var heat_ratio := _overheat / overheat_limit
	_blade_glow.color = Color(overheat_glow, overheat_glow.a * heat_ratio)
	_speed_bar.value = _speed * PERCENT
	_sharpness_bar.value = _sharpness * PERCENT
	var fill_style := _speed_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style != null:
		fill_style.bg_color = too_fast_fill_color if _speed > good_to else speed_fill_color


func _finish_with_medium() -> void:
	_choice_panel.hide()
	_result_panel.hide()
	is_excellent = false
	sharpened.emit(medium_text)
