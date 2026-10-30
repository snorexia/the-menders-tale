class_name DialogueBox
extends Control
## Окно реплики персонажа с вариантами ответа (песочница, #34).
## Разговор — в JSON (формат описан в поле `_note` файла). Окно держится рядом
## с узлом-якорем, даже когда камера осматривает комнату.
## Ответ может требовать предмет, забрать его, дать монеты и сообщить о событии (#37).
## За предмет с меткой `bonus_tag` — ещё `bonus_coins` монет и реплика `bonus_next` (#51).

signal finished
## Выбран ответ с полем `event`: что должно случиться в сцене, например «стражник уходит».
signal event_triggered(event_name: String)

const FADE_TIME := 0.25

## Файл разговора.
@export_file("*.json") var dialogue_path: String
## Возле кого показывать окно, например персонаж.
@export var anchor_node: Node2D
## Сдвиг окна от якоря на экране, px.
@export var anchor_offset: Vector2 = Vector2(300, -600)
## Скорость печати текста, букв в секунду.
@export var characters_per_second: float = 50.0
## Знак перед каждым вариантом ответа.
@export var choice_prefix: String = "▸  "
## Имя, под которым песочница помнит, что разговор закончен: второй раз не начнётся.
## Пусто — не помнить.
@export var memory_key: String = ""

var _nodes: Dictionary = {}
var _start_id: String = ""
var _pending_choices: Array = []
var _typing_tween: Tween

@onready var _bubble: Control = %Bubble
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _text_label: RichTextLabel = %TextLabel
@onready var _choices: VBoxContainer = %Choices


func _ready() -> void:
	hide()
	_load_dialogue(dialogue_path)
	_bubble.gui_input.connect(_on_bubble_gui_input)


func _process(_delta: float) -> void:
	if anchor_node == null or not visible:
		return

	position = anchor_node.get_global_transform_with_canvas().origin + anchor_offset
	# Окно по размеру текста: само по себе оно только растёт и не сжимается обратно.
	_bubble.size = _bubble.get_combined_minimum_size()


## Начать разговор с первой реплики.
func start() -> void:
	if _start_id.is_empty() or _is_finished_before():
		return

	_open()


## Начать другой разговор из файла, даже если основной уже закончен.
func start_other(path: String) -> void:
	_load_dialogue(path)
	if _start_id.is_empty():
		return

	_open()


func _open() -> void:
	modulate.a = 0.0
	show()
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_TIME)
	_show_line(_start_id)


func _is_finished_before() -> bool:
	return not memory_key.is_empty() and SandboxState.finished_dialogues.get(memory_key, false)


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
	_text_label.text = line.get("text", "")
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
		if not needed_item.is_empty() and not SandboxState.has_item(needed_item):
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
	if not memory_key.is_empty():
		SandboxState.finished_dialogues[memory_key] = true

	finished.emit()


func _on_bubble_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return

	_finish_typing()


func _has_bonus(choice: Dictionary) -> bool:
	if not choice.has("bonus_tag") or not choice.has("bonus_next"):
		return false

	return SandboxState.has_tagged_item(choice.get("needs_item", ""), choice["bonus_tag"])


func _apply_choice_effects(choice: Dictionary, take_tag: String) -> void:
	if choice.has("take_item"):
		SandboxState.try_take_item(choice["take_item"], take_tag)
	if choice.has("add_coins"):
		SandboxState.add_coins(int(choice["add_coins"]))
	if choice.has("event"):
		event_triggered.emit(choice["event"])


func _on_choice_pressed(choice: Dictionary) -> void:
	# Метку проверяем до эффектов: они могут забрать предмет.
	var has_bonus := _has_bonus(choice)
	_apply_choice_effects(choice, choice.get("bonus_tag", "") if has_bonus else "")
	if has_bonus:
		SandboxState.add_coins(int(choice.get("bonus_coins", 0)))
		_show_line(choice["bonus_next"])
	elif choice.has("next"):
		_show_line(choice["next"])
	elif choice.has("scene"):
		get_tree().change_scene_to_file(choice["scene"])
	else:
		_close()
