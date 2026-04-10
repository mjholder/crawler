class_name RestPanel
extends Control

# --- Signals ---

signal rest_requested
signal rest_complete

# --- Node References ---

@onready var _title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $PanelContainer/VBoxContainer/DescriptionLabel
@onready var _rest_button: Button = $PanelContainer/VBoxContainer/RestButton
@onready var _continue_button: Button = $PanelContainer/VBoxContainer/ContinueButton


func _ready() -> void:
	_continue_button.hide()
	_rest_button.pressed.connect(_on_rest_button_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)


func setup(heal_amount: float) -> void:
	_title_label.text = "Rest Site"
	_description_label.text = "Restore %.0f health" % heal_amount
	_rest_button.disabled = false
	_continue_button.hide()


# --- Handlers ---

func _on_rest_button_pressed() -> void:
	_rest_button.disabled = true
	_continue_button.show()
	_description_label.text = "You feel refreshed."
	rest_requested.emit()


func _on_continue_pressed() -> void:
	rest_complete.emit()
