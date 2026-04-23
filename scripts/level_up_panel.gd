class_name LevelUpPanel
extends Control

# --- Signals ---
signal level_up_confirmed

# --- Node References ---
@onready var _title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var _points_label: Label = $PanelContainer/VBoxContainer/PointsContainer/PointsLabel
@onready var _confirm_button: Button = $PanelContainer/VBoxContainer/ConfirmButton

var _player: Player = null
# Enums.Stat (int) -> int, points spent this panel session
var _session_allocations: Dictionary = {}
# Enums.Stat (int) -> float, base value before growth and session spend
var _pre_session_bases: Dictionary = {}

# Row node bundles keyed by Enums.Stat (int)
var _rows: Dictionary = {}


func _ready() -> void:
	_rows = {
		Enums.Stat.STRENGTH:     _build_row_ref("StrengthContainer"),
		Enums.Stat.CONSTITUTION: _build_row_ref("ConstitutionContainer"),
		Enums.Stat.AGILITY:      _build_row_ref("AgilityContainer"),
		Enums.Stat.SPIRIT:       _build_row_ref("SpiritContainer"),
		Enums.Stat.LUCK:         _build_row_ref("LuckContainer"),
	}
	for stat_key in _rows:
		var row: Dictionary = _rows[stat_key]
		row.plus.pressed.connect(_on_plus_pressed.bind(stat_key as Enums.Stat))
		row.minus.pressed.connect(_on_minus_pressed.bind(stat_key as Enums.Stat))
	_confirm_button.pressed.connect(_on_confirm_pressed)


func _build_row_ref(container_name: String) -> Dictionary:
	var container: HBoxContainer = $PanelContainer/VBoxContainer/StatsContainer.get_node(container_name)
	return {
		number = container.get_node("NumberLabel") as Label,
		bonus  = container.get_node("BonusLabel") as Label,
		plus   = container.get_node("PlusButton") as Button,
		minus  = container.get_node("MinusButton") as Button,
	}


## Called by game.gd before showing the panel.
func setup(player: Player) -> void:
	_player = player
	_session_allocations = {}
	_pre_session_bases = {}
	for stat_key in _rows:
		var growth: float = _player.pending_growth_bonuses.get(stat_key, 0.0)
		_pre_session_bases[stat_key] = _player.get_base_stat(stat_key as Enums.Stat) - growth
	_refresh()


func _refresh() -> void:
	if _player == null:
		return
	_title_label.text = "Level Up!  You are now level %d." % _player.level
	_points_label.text = "Points remaining: %d" % _player.pending_stat_points
	_confirm_button.disabled = _player.pending_stat_points > 0
	for stat_key in _rows:
		var row: Dictionary = _rows[stat_key]
		var growth: float = _player.pending_growth_bonuses.get(stat_key, 0.0)
		var spent: int = _session_allocations.get(stat_key, 0)
		var pre_base: float = _pre_session_bases.get(stat_key, 0.0)
		row.number.text = "%d" % int(pre_base)
		row.bonus.text = "+%d" % (int(growth) + spent)
		if growth > 0.0:
			row.bonus.add_theme_color_override("font_color", Color.GREEN)
		else:
			row.bonus.remove_theme_color_override("font_color")
		row.minus.disabled = spent <= 0
		row.plus.disabled = _player.pending_stat_points <= 0


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
	_player.clear_pending_growth_bonuses()
	level_up_confirmed.emit()
