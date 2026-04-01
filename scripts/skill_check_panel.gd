class_name SkillCheckPanel
extends Control

# --- Signals ---

signal skill_check_complete(success: bool)

# --- Node References ---

@onready var _stat_name_label: Label = $PanelContainer/VBoxContainer/HBoxContainer/StatNameLabel
@onready var _stat_value_label: Label = $PanelContainer/VBoxContainer/HBoxContainer/StatValueLabel
@onready var _prompt_label: Label = $PanelContainer/VBoxContainer/PromptLabel
@onready var _roll_result_label: Label = $PanelContainer/VBoxContainer/RollResultLabel
@onready var _roll_button: Button = $PanelContainer/VBoxContainer/RollButton
@onready var _continue_button: Button = $PanelContainer/VBoxContainer/ContinueButton

# --- State ---

var _stat_value: float
var _success: bool


func _ready() -> void:
	_roll_result_label.hide()
	_continue_button.hide()
	_roll_button.pressed.connect(_on_roll_button_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)


func setup(stat_name: String, label: String, stat_value: float) -> void:
	_stat_name_label.text = stat_name
	_stat_value_label.text = str(int(stat_value))
	_prompt_label.text = label
	_stat_value = stat_value
	_roll_result_label.hide()
	_continue_button.hide()
	_roll_button.disabled = false


# --- Handlers ---

func _on_roll_button_pressed() -> void:
	var roll: int = randi_range(1, 100)
	_success = roll <= int(_stat_value)
	var result_text: String = "SUCCESS" if _success else "FAILURE"
	_roll_result_label.text = "Rolled: %d — %s" % [roll, result_text]
	_roll_result_label.show()
	_roll_button.disabled = true
	_continue_button.show()


func _on_continue_pressed() -> void:
	skill_check_complete.emit(_success)
