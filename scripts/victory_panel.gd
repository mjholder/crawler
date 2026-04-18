class_name VictoryPanel
extends Control

# --- Signals ---

signal main_menu_requested

# --- Node References ---

@onready var _main_menu_button: Button = $PanelContainer/VBoxContainer/MainMenuButton


func _ready() -> void:
	_main_menu_button.pressed.connect(_on_main_menu_pressed)


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()
