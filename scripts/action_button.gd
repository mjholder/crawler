class_name ActionButtonUI
extends Control

# --- Signals ---
signal pressed

# --- Node References ---
@onready var _button: Button = $ActionButton
@onready var _label: Label = $ActionLabel
@onready var _cost_container: PanelContainer = $SpellCostContainer
@onready var _cost_label: Label = $SpellCostContainer/SpellCostLabel

# --- State ---
var hand: int = -1
var action_name: String = ""
var cost: float = 0.0


func _ready() -> void:
	_button.pressed.connect(func() -> void: pressed.emit())


## Sets the action name and shows/hides the cost badge (hidden when cost <= 0).
func configure(p_hand: int, p_action_name: String, p_cost: float) -> void:
	hand = p_hand
	action_name = p_action_name
	cost = p_cost
	_label.text = p_action_name
	_cost_container.visible = p_cost > 0.0
	if p_cost > 0.0:
		_cost_label.text = str(int(p_cost))


func set_disabled(value: bool) -> void:
	_button.disabled = value


func set_highlighted(value: bool) -> void:
	modulate = Color(1.4, 1.4, 0.6) if value else Color.WHITE


func set_focus_enabled(value: bool) -> void:
	_button.focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE
