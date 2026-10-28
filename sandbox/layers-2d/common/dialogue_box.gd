class_name DialogueBox
extends Control
## Окно реплики персонажа с вариантами ответа (песочница, #34).
## Разговор — в JSON (формат описан в поле `_note` файла). Окно держится рядом
## с узлом-якорем, даже когда камера осматривает комнату.

signal finished

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
	_load_dialogue()
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

	modulate.a = 0.0
	show()
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_TIME)
	_show_line(_start_id)


func _is_finished_before() -> bool:
	return not memory_key.is_empty() and SandboxState.finished_dialogues.get(memory_key, false)


func _load_dialogue() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(dialogue_path))
	if not data is Dictionary:
		push_warning("DialogueBox: не удалось прочитать %s" % dialogue_path)
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


func _on_choice_pressed(choice: Dictionary) -> void:
	if choice.has("next"):
		_show_line(choice["next"])
	elif choice.has("scene"):
		get_tree().change_scene_to_file(choice["scene"])
	else:
		_close()
