class_name DialoguePanel
extends Control

# --- Signals ---

signal dialogue_complete(terminal_node_id: String)

# --- Node References ---

@onready var _speaker_label: Label = $SpeakerLabel
@onready var _text_label: RichTextLabel = $TextLabel
@onready var _choices_container: VBoxContainer = $ChoicesContainer

@export var _choice_button: PackedScene

# --- State ---

var _data: Dictionary
var _consequences: DialogueConsequences
var _current_node_id: String

# --- Setup ---

func load_dialogue(data: Dictionary, consequences: DialogueConsequences) -> void:
	_data = data
	_consequences = consequences
	_load_node("0")

# --- Node Navigation ---

func _load_node(node_id: String) -> void:
	_current_node_id = node_id
	var node: Dictionary = _data["nodes"][node_id]

	if node["consequence"] != null:
		var consequences: Dictionary = node["consequence"]
		_consequences.execute(consequences["action"], consequences["value"])

	_render_node(node)

func _render_node(node: Dictionary) -> void:
	if node["speaker"] == null:
		_speaker_label.hide()
	else:
		_speaker_label.text = node["speaker"]
		_speaker_label.show()

	_text_label.text = node["text"]

	for child in _choices_container.get_children():
		child.queue_free()

	if node["choices"].is_empty():
		var button: Button = _choice_button.instantiate()
		button.text = "Continue"
		button.pressed.connect(_on_continue_pressed)
		_choices_container.add_child(button)
		return

	for i: int in node["choices"].size():
		var button: Button = _choice_button.instantiate()
		button.text = node["choices"][i]["text"]
		button.pressed.connect(_on_choice_pressed.bind(i))
		_choices_container.add_child(button)

# --- Handlers ---

func _on_choice_pressed(index: int) -> void:
	var next_id: String = _data["nodes"][_current_node_id]["choices"][index]["next"]
	_load_node(next_id)

func _on_continue_pressed() -> void:
	dialogue_complete.emit(_current_node_id)
