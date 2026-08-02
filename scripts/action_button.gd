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
var _disabled: bool = false
var _highlighted: bool = false


func _ready() -> void:
	_button.pressed.connect(func() -> void: pressed.emit())


## Sets the action name, cost badge (hidden when cost <= 0), and cooldown badge
## (a turns-remaining number shown, with the button dimmed, while cooldown > 0).
func configure(p_hand: int, p_action_name: String, p_cost: float, p_cooldown_remaining: int = 0, p_tooltip: String = "") -> void:
	hand = p_hand
	action_name = p_action_name
	cost = p_cost
	cooldown_remaining = p_cooldown_remaining
	_label.text = p_action_name
	_button.tooltip_text = p_tooltip
	_cost_container.visible = p_cost > 0.0
	if p_cost > 0.0:
		_cost_label.text = str(int(p_cost))
	_cooldown_container.visible = p_cooldown_remaining > 0
	if p_cooldown_remaining > 0:
		_cooldown_label.text = str(p_cooldown_remaining)
	_update_visual()


func set_disabled(value: bool) -> void:
	_disabled = value
	_button.disabled = value
	_update_visual()


func set_highlighted(value: bool) -> void:
	_highlighted = value
	_update_visual()


## Single source of truth for the button tint. The overlaid label hides the Button's own
## disabled shading, so dim the whole control instead: highlighted wins, then a cooling-down
## action reads at 0.6, then a plain disabled action (e.g. its hand is spent) reads darker.
func _update_visual() -> void:
	if _highlighted:
		modulate = Color(1.4, 1.4, 0.6)
	elif cooldown_remaining > 0:
		modulate = Color(0.6, 0.6, 0.6)
	elif _disabled:
		modulate = Color(0.45, 0.45, 0.45)
	else:
		modulate = Color.WHITE


func set_focus_enabled(value: bool) -> void:
	_button.focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE
