class_name ActionButtonUI
extends Control

# --- Signals ---
signal pressed

# --- Node References ---
@onready var _button: Button = $ActionButton
@onready var _label: Label = $ActionLabel
@onready var _cost_container: PanelContainer = $SpellCostContainer
@onready var _cost_label: Label = $SpellCostContainer/SpellCostLabel
@onready var _cooldown_container: PanelContainer = $CooldownContainer
@onready var _cooldown_label: Label = $CooldownContainer/CooldownLabel

# --- State ---
var hand: int = -1
var action_name: String = ""
var cost: float = 0.0
var cooldown_remaining: int = 0


func _ready() -> void:
	_button.pressed.connect(func() -> void: pressed.emit())


## Sets the action name, cost badge (hidden when cost <= 0), and cooldown badge
## (a turns-remaining number shown, with the button dimmed, while cooldown > 0).
func configure(p_hand: int, p_action_name: String, p_cost: float, p_cooldown_remaining: int = 0) -> void:
	hand = p_hand
	action_name = p_action_name
	cost = p_cost
	cooldown_remaining = p_cooldown_remaining
	_label.text = p_action_name
	_cost_container.visible = p_cost > 0.0
	if p_cost > 0.0:
		_cost_label.text = str(int(p_cost))
	_cooldown_container.visible = p_cooldown_remaining > 0
	if p_cooldown_remaining > 0:
		_cooldown_label.text = str(p_cooldown_remaining)
	# Dim a cooling-down action so it reads distinctly from a plain disabled button.
	modulate = Color(0.6, 0.6, 0.6) if p_cooldown_remaining > 0 else Color.WHITE


func set_disabled(value: bool) -> void:
	_button.disabled = value


func set_highlighted(value: bool) -> void:
	if value:
		modulate = Color(1.4, 1.4, 0.6)
	else:
		modulate = Color(0.6, 0.6, 0.6) if cooldown_remaining > 0 else Color.WHITE


func set_focus_enabled(value: bool) -> void:
	_button.focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE
