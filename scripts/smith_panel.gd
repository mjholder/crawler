class_name SmithPanel
extends Control

# --- Signals ---

## The player chose to smith the weapon at `index` in the list last passed to setup()/refresh().
## game.gd rebuilds the same-ordered list to resolve the index back to an ItemInstance.
signal upgrade_requested(index: int)
signal leave_requested

# --- Node References ---

@onready var _title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var _description_label: Label = $PanelContainer/VBoxContainer/DescriptionLabel
@onready var _gold_label: Label = $PanelContainer/VBoxContainer/GoldLabel
@onready var _weapon_list: VBoxContainer = $PanelContainer/VBoxContainer/WeaponList
@onready var _empty_label: Label = $PanelContainer/VBoxContainer/EmptyLabel
@onready var _leave_button: Button = $PanelContainer/VBoxContainer/LeaveButton

# --- State ---

var _cost: int = 0


func _ready() -> void:
	_leave_button.pressed.connect(func() -> void: leave_requested.emit())


## Seeds the picker with the upgradable weapons (each an ItemInstance whose base is WeaponData),
## the player's current gold, and the flat smith cost.
func setup(weapons: Array, player_gold: int, cost: int) -> void:
	_cost = cost
	refresh(weapons, player_gold)


## Rebuilds the rows and the gold / affordability state — called after each smith so the upgrade
## level preview and disabled states update in place while the panel stays open.
func refresh(weapons: Array, player_gold: int) -> void:
	_gold_label.text = "Gold: %d" % player_gold
	for child in _weapon_list.get_children():
		child.queue_free()
	_empty_label.visible = weapons.is_empty()
	for i in weapons.size():
		var inst: ItemInstance = weapons[i]
		var weapon_name: String = inst.base.item_name if inst.base.item_name != "" else "Weapon"
		var btn := Button.new()
		btn.add_theme_font_size_override("font_size", 20)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = "%s  (+%d)   —   Smith (%dg)" % [weapon_name, inst.upgrade_level, _cost]
		btn.disabled = player_gold < _cost
		btn.pressed.connect(_on_row_pressed.bind(i))
		_weapon_list.add_child(btn)


func _on_row_pressed(index: int) -> void:
	upgrade_requested.emit(index)
