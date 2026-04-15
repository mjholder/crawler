class_name LevelUpPanel
extends Control

# --- Signals ---
signal level_up_confirmed

# --- Node References ---
# Expected scene layout:
#   PanelContainer/VBoxContainer/
#     TitleLabel     (Label)   "Level Up! You are now level N"
#     PointsLabel    (Label)   "Points remaining: N"
#     StatsContainer (VBoxContainer)  — stat rows added dynamically
#     ConfirmButton  (Button)
@onready var _title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var _points_label: Label = $PanelContainer/VBoxContainer/PointsLabel
@onready var _stats_container: VBoxContainer = $PanelContainer/VBoxContainer/StatsContainer
@onready var _confirm_button: Button = $PanelContainer/VBoxContainer/ConfirmButton

var _player: Player = null
# Tracks points spent in this session so we can undo before confirming.
# Enums.Stat (int) -> int count
var _session_allocations: Dictionary = {}
# Direct references to row widgets, keyed by Enums.Stat (int).
var _stat_labels: Dictionary = {}
var _minus_buttons: Dictionary = {}
var _plus_buttons: Dictionary = {}


func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)


## Called by game.gd before showing the panel.
func setup(player: Player) -> void:
	_player = player
	_session_allocations = {}
	_rebuild_stat_rows()
	_refresh()


func _rebuild_stat_rows() -> void:
	for child in _stats_container.get_children():
		child.queue_free()
	_stat_labels.clear()
	_minus_buttons.clear()
	_plus_buttons.clear()
	var stat_names := Enums.Stat.keys()
	for stat_key in Enums.Stat.values():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.custom_minimum_size = Vector2(200, 0)
		label.text = "%s: %.0f" % [stat_names[stat_key], _player.get_effective_stat(stat_key as Enums.Stat)]
		var minus_btn := Button.new()
		minus_btn.text = "-"
		minus_btn.pressed.connect(_on_minus_pressed.bind(stat_key as Enums.Stat))
		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.pressed.connect(_on_plus_pressed.bind(stat_key as Enums.Stat))
		row.add_child(label)
		row.add_child(minus_btn)
		row.add_child(plus_btn)
		_stats_container.add_child(row)
		_stat_labels[stat_key] = label
		_minus_buttons[stat_key] = minus_btn
		_plus_buttons[stat_key] = plus_btn


func _refresh() -> void:
	if _player == null:
		return
	_title_label.text = "Level Up!  You are now level %d." % _player.level
	_points_label.text = "Points remaining: %d" % _player.pending_stat_points
	_confirm_button.disabled = _player.pending_stat_points > 0
	var stat_names := Enums.Stat.keys()
	for stat_key in Enums.Stat.values():
		var label: Label = _stat_labels.get(stat_key)
		var minus_btn: Button = _minus_buttons.get(stat_key)
		var plus_btn: Button = _plus_buttons.get(stat_key)
		if label == null:
			continue
		var value: float = _player.get_effective_stat(stat_key as Enums.Stat)
		label.text = "%s: %.0f" % [stat_names[stat_key], value]
		var spent_on_this: int = _session_allocations.get(stat_key, 0)
		minus_btn.disabled = spent_on_this <= 0
		plus_btn.disabled = _player.pending_stat_points <= 0


func _on_plus_pressed(stat: Enums.Stat) -> void:
	if _player == null or _player.pending_stat_points <= 0:
		return
	_player.spend_stat_point(stat)
	_session_allocations[stat] = _session_allocations.get(stat, 0) + 1
	_refresh()


func _on_minus_pressed(stat: Enums.Stat) -> void:
	if _player == null or _session_allocations.get(stat, 0) <= 0:
		return
	_player.unspend_stat_point(stat)
	_session_allocations[stat] = _session_allocations.get(stat, 0) - 1
	_refresh()


func _on_confirm_pressed() -> void:
	if _player != null and _player.pending_stat_points > 0:
		return
	level_up_confirmed.emit()
