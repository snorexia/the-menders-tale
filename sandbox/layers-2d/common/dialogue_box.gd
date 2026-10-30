class_name DialogueBox
extends Control
## Окно реплики персонажа с вариантами ответа (песочница, #34).
## Разговор — в JSON (формат описан в поле `_note` файла). Окно держится рядом
## с узлом-якорем, даже когда камера осматривает комнату.
## Ответ может требовать предмет, забрать его, дать монеты и сообщить о событии (#37).
## `pay_item_price` — платит цену забранного предмета, в реплике это `{coins}` (#51).
## `needs_grade` — предмет не хуже этого итога, `next_by_grade` — реплика по итогу вещи (#56).
## `start_quest` и `complete_quest` — выдать и закончить задание, `give_item` — дать предмет.

signal finished
## Выбран ответ с полем `event`: что должно случиться в сцене, например «стражник уходит».
signal event_triggered(event_name: String)

const FADE_TIME := 0.25
## Отступ окна от края экрана: камера не должна увести его за край, px.
const SCREEN_MARGIN := 16.0

## Скорость печати текста, букв в секунду.
@export var characters_per_second: float = 50.0
## Знак перед каждым вариантом ответа.
@export var choice_prefix: String = "▸  "

var _anchor_node: Node2D
var _anchor_offset: Vector2 = Vector2.ZERO
var _nodes: Dictionary = {}
var _start_id: String = ""
var _pending_choices: Array = []
var _typing_tween: Tween
var _paid_coins: int = 0

@onready var _tail: Node2D = $Tail
@onready var _bubble: Control = %Bubble
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _text_label: RichTextLabel = %TextLabel
@onready var _choices: VBoxContainer = %Choices


func _ready() -> void:
	hide()
	_bubble.gui_input.connect(_on_bubble_gui_input)


func _process(_delta: float) -> void:
	if _anchor_node == null or not visible:
		return

	# Окно по размеру текста: само по себе оно только растёт и не сжимается обратно.
	_bubble.size = _bubble.get_combined_minimum_size()
	var is_on_left := _anchor_offset.x < 0.0
	var offset := _anchor_offset
	if is_on_left:
		offset.x -= _bubble.size.x

	position = _anchor_node.get_global_transform_with_canvas().origin + offset
	var max_x := get_viewport_rect().size.x - _bubble.size.x - SCREEN_MARGIN
	position.x = clampf(position.x, SCREEN_MARGIN, max_x)
	_tail.scale.x = -1.0 if is_on_left else 1.0
	_tail.position.x = _bubble.size.x if is_on_left else 0.0


## Начать разговор из файла рядом с персонажем. Сдвиг окна — от него на экране, px;
## отрицательный X — окно слева от него.
func start(path: String, anchor: Node2D, anchor_offset: Vector2) -> void:
	_anchor_node = anchor
	_anchor_offset = anchor_offset
	_load_dialogue(path)
	if _start_id.is_empty():
		return

	modulate.a = 0.0
	show()
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_TIME)
	_show_line(_start_id)


func _load_dialogue(path: String) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("DialogueBox: не удалось прочитать %s" % path)
		return

	_nodes = data.get("nodes", {})
	_start_id = data.get("start", "")


func _show_line(line_id: String) -> void:
	var line: Dictionary = _nodes.get(line_id, {})
	_speaker_label.text = line.get("speaker", "")
	_text_label.text = str(line.get("text", "")).replace("{coins}", str(_paid_coins))
	_pending_choices = line.get("choices", [])
	_clear_choices()

	_text_label.visible_ratio = 0.0
	var typing_time := _text_label.get_total_character_count() / characters_per_second
	_typing_tween = create_tween()
	_typing_tween.tween_property(_text_label, "visible_ratio", 1.0, typing_time)
	_typing_tween.tween_callback(_show_choices)


func _finish_typing() -> void:
	if _typing_tween == null or not _typing_tween.is_running():
		return

	_typing_tween.kill()
	_text_label.visible_ratio = 1.0
	_show_choices()


func _show_choices() -> void:
	for choice: Dictionary in _pending_choices:
		var button := Button.new()
		button.text = choice_prefix + str(choice.get("text", ""))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var needed_item: String = choice.get("needs_item", "")
		var needed_grade: String = choice.get("needs_grade", "")
		if not needed_item.is_empty() and not SandboxState.has_item(needed_item, needed_grade):
			button.text += str(choice.get("missing_text", ""))
			button.disabled = true

		button.pressed.connect(_on_choice_pressed.bind(choice))
		_choices.add_child(button)


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


func _close() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(hide)
	finished.emit()


func _on_bubble_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return

	_finish_typing()


func _apply_choice_effects(choice: Dictionary) -> void:
	if choice.has("take_item"):
		var min_grade: String = choice.get("needs_grade", "")
		if choice.get("pay_item_price", false):
			_paid_coins = SandboxState.get_item_price(choice["take_item"], min_grade)
			SandboxState.add_coins(_paid_coins)

		SandboxState.try_take_item(choice["take_item"], min_grade)
	if choice.has("add_coins"):
		SandboxState.add_coins(int(choice["add_coins"]))
	if choice.has("give_item"):
		SandboxState.add_item(choice["give_item"])
	if choice.has("start_quest"):
		SandboxState.start_quest(choice["start_quest"])
	if choice.has("complete_quest"):
		SandboxState.complete_quest(choice["complete_quest"])
	if choice.has("event"):
		event_triggered.emit(choice["event"])


func _on_choice_pressed(choice: Dictionary) -> void:
	# Итог смотрим до эффектов: они забирают предмет.
	var taken_item: String = choice.get("take_item", "")
	var grade := SandboxState.get_item_grade(taken_item, choice.get("needs_grade", ""))
	_apply_choice_effects(choice)
	var next_line: String = choice.get("next_by_grade", {}).get(grade, choice.get("next", ""))
	if not next_line.is_empty():
		_show_line(next_line)
	elif choice.has("scene"):
		get_tree().change_scene_to_file(choice["scene"])
	else:
		_close()
