class_name TownPanel
extends Control

# --- Signals ---

## A town service was chosen. Extend with more services (shop, trainer, …) here.
signal temple_requested
signal smith_requested
signal travel_requested

# --- Node References ---

@onready var _temple_button: Button = $PanelContainer/VBoxContainer/Services/TempleButton
@onready var _smith_button: Button = $PanelContainer/VBoxContainer/Services/SmithButton
@onready var _travel_button: Button = $PanelContainer/VBoxContainer/TravelButton


func _ready() -> void:
	_temple_button.pressed.connect(func() -> void: temple_requested.emit())
	_smith_button.pressed.connect(func() -> void: smith_requested.emit())
	_travel_button.pressed.connect(func() -> void: travel_requested.emit())
