class_name ShrinePanel
extends Control

# --- Signals ---

signal ascend_requested
signal leave_requested

# --- Node References ---

@onready var _title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $PanelContainer/VBoxContainer/DescriptionLabel
@onready var _stats_label: Label = $PanelContainer/VBoxContainer/StatsLabel
@onready var _cost_label: Label = $PanelContainer/VBoxContainer/CostLabel
@onready var _ascend_button: Button = $PanelContainer/VBoxContainer/AscendButton
@onready var _leave_button: Button = $PanelContainer/VBoxContainer/LeaveButton


func _ready() -> void:
	_ascend_button.pressed.connect(func() -> void: ascend_requested.emit())
	_leave_button.pressed.connect(func() -> void: leave_requested.emit())


func setup(
	saint_name: String,
	has_next: bool,
	next_tier_name: String,
	next_tier_desc: String,
	next_stat_mods: Dictionary,
	cost: int,
	player_gold: int
) -> void:
	_title_label.text = saint_name if saint_name != "" else "Forgotten Shrine"

	if not has_next:
		_description_label.text = (
			"The shrine is silent. There is nothing more it can offer you."
			if saint_name != ""
			else "No saint watches over you. The shrine stays silent."
		)
		_stats_label.hide()
		_cost_label.hide()
		_ascend_button.hide()
		_leave_button.text = "Leave"
		return

	_description_label.text = "Ascend to %s.\n%s" % [next_tier_name, next_tier_desc]

	var stats_text := _format_stat_modifiers(next_stat_mods)
	_stats_label.text = stats_text
	_stats_label.visible = stats_text != ""

	_cost_label.show()
	_cost_label.text = "Tithe: %d gold   (you have %d)" % [cost, player_gold]

	_ascend_button.show()
	var can_afford := player_gold >= cost
	_ascend_button.disabled = not can_afford
	_ascend_button.text = "Ascend (%d gold)" % cost if can_afford else "Not enough gold"
	_leave_button.text = "Leave"


func _format_stat_modifiers(modifiers: Dictionary) -> String:
	if modifiers.is_empty():
		return ""
	var stat_names := Enums.Stat.keys()
	var lines: Array[String] = []
	for stat_key in modifiers:
		var value: float = modifiers[stat_key]
		var name: String = stat_names[stat_key] if stat_key < stat_names.size() else str(stat_key)
		var sign: String = "+" if value >= 0.0 else ""
		var formatted: String = str(int(value)) if value == floorf(value) else "%.1f" % value
		lines.append(sign + formatted + " " + name)
	return "\n".join(lines)
