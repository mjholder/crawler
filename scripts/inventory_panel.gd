class_name InventoryPanel
extends Control

# --- Node References ---

@onready var _paper_doll: PaperDoll = get_node_or_null("HBoxContainer/PaperDollPanel/PaperDoll")
@onready var _equipped_slots: VBoxContainer = $HBoxContainer/PanelContainer/VBoxContainer/EquippedSlots
@onready var _bag_grid: GridContainer = $HBoxContainer/PanelContainer/VBoxContainer/BagGrid
@onready var _detail_name_label: Label = $HBoxContainer/DetailPanel/VBoxContainer/DetailNameLabel
@onready var _detail_stats_label: Label = $HBoxContainer/DetailPanel/VBoxContainer/DetailStatsLabel

# --- Constants ---

# Names match Enums.Slot definition order: WEAPON, HANDS, FEET, LEGS, TORSO, HEAD
const _SLOT_CONTAINER_NAMES: Array[String] = [
	"WeaponEquipment", "HandsEquipment", "FeetEquipment",
	"LegsEquipment", "TorsoEquipment", "HeadEquipment", "OffhandEquipment"
]
const _RING_CONTAINER_NAMES: Array[String] = ["RingEquipment1", "RingEquipment2"]
const _SLOT_HIGHLIGHT := Color(1.4, 1.4, 0.6)

# --- State ---

var _inventory: Inventory
var _player: Player = null
var _slot_buttons: Array[Button] = []
var _ring_buttons: Array[Button] = []
var _bag_buttons: Array[Button] = []
var _prep_buttons: Array[Button] = []
var _prep_container: VBoxContainer = null
var _can_equip: bool = true
var _dungeon_locked: bool = false

# Hand-selection state: while a weapon flagged EITHER awaits a hand choice, the candidate
# slot buttons highlight and the arrow keys cycle between them (mirrors combat targeting).
var _selecting_hand_data: WeaponData = null
var _slot_choice_candidates: Array[Enums.Slot] = []
var _slot_choice_index: int = 0


func _ready() -> void:
	_collect_node_refs()
	_connect_buttons()
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	# Closing the panel mid-choice (e.g. Esc handled elsewhere) cancels the selection so the
	# highlight and button focus don't linger.
	if not visible and _selecting_hand_data != null:
		_cancel_slot_choice()


func set_can_equip(value: bool) -> void:
	_can_equip = value
	_apply_equip_state()


func set_dungeon_locked(locked: bool) -> void:
	_dungeon_locked = locked
	_apply_equip_state()


func unequip_belt_slot(index: int) -> void:
	if _inventory != null:
		_inventory.unequip_consumable(index)


func _apply_equip_state() -> void:
	var active := _can_equip and not _dungeon_locked
	for btn in _slot_buttons:
		btn.disabled = not active
	for btn in _ring_buttons:
		btn.disabled = not active
	for btn in _bag_buttons:
		btn.disabled = not active
	for btn in _prep_buttons:
		btn.disabled = _dungeon_locked


func setup(inventory: Inventory) -> void:
	_inventory = inventory
	_inventory.slot_changed.connect(_on_slot_changed)
	_inventory.ring_changed.connect(_on_ring_changed)
	_inventory.bag_changed.connect(_refresh_bag)
	_refresh_slots()
	_refresh_rings()
	_refresh_bag()
	_hide_detail()
	if _paper_doll != null:
		_paper_doll.setup(inventory)


# --- Node Collection ---

func _collect_node_refs() -> void:
	for name in _SLOT_CONTAINER_NAMES:
		var container := _equipped_slots.get_node(name) as Control
		_slot_buttons.append(container.get_node("EquipmentButton") as Button)
	for name in _RING_CONTAINER_NAMES:
		var container := _equipped_slots.get_node(name) as Control
		_ring_buttons.append(container.get_node("EquipmentButton") as Button)
	for child in _bag_grid.get_children():
		if child is Button:
			_bag_buttons.append(child as Button)


func _connect_buttons() -> void:
	for i in _slot_buttons.size():
		_slot_buttons[i].pressed.connect(_on_slot_button_pressed.bind(i as Enums.Slot))
		_slot_buttons[i].mouse_entered.connect(_on_slot_button_hovered.bind(i as Enums.Slot))
		_slot_buttons[i].mouse_exited.connect(_hide_detail)
	for i in _ring_buttons.size():
		_ring_buttons[i].pressed.connect(_on_ring_button_pressed.bind(i))
		_ring_buttons[i].mouse_entered.connect(_on_ring_button_hovered.bind(i))
		_ring_buttons[i].mouse_exited.connect(_hide_detail)
	for i in _bag_buttons.size():
		_bag_buttons[i].pressed.connect(_on_bag_button_pressed.bind(i))
		_bag_buttons[i].mouse_entered.connect(_on_bag_button_hovered.bind(i))
		_bag_buttons[i].mouse_exited.connect(_hide_detail)


# --- Refresh ---

func _refresh_slots() -> void:
	for i in _slot_buttons.size():
		var data: EquipmentData = _inventory.get_equipped(i as Enums.Slot)
		_slot_buttons[i].text = data.item_name if data else "—"


func _refresh_rings() -> void:
	var rings := _inventory.get_rings()
	for i in _ring_buttons.size():
		var data: EquipmentData = rings[i] if i < rings.size() else null
		_ring_buttons[i].text = data.item_name if data else "—"


func _refresh_bag() -> void:
	var bag := _inventory.get_bag()
	var active := _can_equip and not _dungeon_locked
	for i in _bag_buttons.size():
		if i < bag.size():
			_bag_buttons[i].text = bag[i].item_name
			_bag_buttons[i].disabled = not active
		else:
			_bag_buttons[i].text = ""
			_bag_buttons[i].disabled = true


# --- Signal Handlers ---

func _on_slot_changed(_slot: Enums.Slot, _new: EquipmentData, _old: EquipmentData) -> void:
	_refresh_slots()


func _on_ring_changed(_index: int, _new: EquipmentData, _old: EquipmentData) -> void:
	_refresh_rings()


# --- Button Handlers ---

func _on_slot_button_pressed(slot: Enums.Slot) -> void:
	if _inventory == null:
		return
	# While choosing a hand, clicking a candidate slot confirms that choice.
	if _selecting_hand_data != null:
		if slot in _slot_choice_candidates:
			_slot_choice_index = _slot_choice_candidates.find(slot)
			_confirm_slot_choice()
		return
	if _inventory.get_equipped(slot) != null:
		_inventory.unequip(slot)


func _on_ring_button_pressed(index: int) -> void:
	if _inventory == null:
		return
	var rings := _inventory.get_rings()
	if index < rings.size() and rings[index] != null:
		_inventory.unequip_ring(index)


func _on_bag_button_pressed(index: int) -> void:
	if _inventory == null:
		return
	var bag := _inventory.get_bag()
	if index >= bag.size():
		return
	var data: EquipmentData = bag[index]
	# A tome isn't equipped — using it consumes the tome and teaches its spell. Buttons are
	# disabled under the dungeon lock, so removal always succeeds here.
	if data is TomeData:
		var tome := data as TomeData
		if _player == null or tome.spell == null:
			return
		_inventory.remove_from_bag(data)
		_player.learn_spell(tome.spell)
		return
	# An EITHER weapon needs a hand chosen first; defer removing it from the bag until the
	# player confirms, so cancelling never loses the item.
	if _should_prompt_for_hand(data):
		_begin_slot_selection(data as WeaponData)
		return
	var target_slot := _target_slot_for(data)
	# An OFFHAND_ONLY weapon can't be equipped while a two-hander locks the offhand.
	if not data.is_ring and not (data is ConsumableData) and _inventory.is_slot_locked(target_slot):
		return
	_inventory.remove_from_bag(data)
	if data is ConsumableData:
		if not _inventory.equip_consumable(data as ConsumableData):
			_inventory.add_to_bag(data)
	elif data.is_ring:
		_inventory.equip_ring(data)
	else:
		_inventory.equip(target_slot, data)


# --- Hand Selection ---

## Resolves which slot an item equips into. Weapons route by hand_restriction; everything
## else uses its authored slot. EITHER resolves to WEAPON here (used only when the offhand
## is locked and no prompt is shown).
func _target_slot_for(data: EquipmentData) -> Enums.Slot:
	if data is WeaponData:
		if (data as WeaponData).hand_restriction == Enums.HandRestriction.OFFHAND_ONLY:
			return Enums.Slot.OFFHAND
		return Enums.Slot.WEAPON
	return data.slot


func _should_prompt_for_hand(data: EquipmentData) -> bool:
	if not data is WeaponData:
		return false
	if (data as WeaponData).hand_restriction != Enums.HandRestriction.EITHER:
		return false
	# With the offhand locked by a two-hander there's only one valid hand — no prompt.
	return not _inventory.is_slot_locked(Enums.Slot.OFFHAND)


func _begin_slot_selection(data: WeaponData) -> void:
	_selecting_hand_data = data
	_slot_choice_candidates = [Enums.Slot.WEAPON, Enums.Slot.OFFHAND]
	_slot_choice_index = 0
	# Disable every button except the candidate slots so the rest of the inventory greys out and
	# can't steal keyboard focus. FOCUS_NONE on the candidates keeps them clickable-to-confirm
	# without capturing the arrow keys (a click doesn't need focus).
	for i in _slot_buttons.size():
		_slot_buttons[i].disabled = (i as Enums.Slot) not in _slot_choice_candidates
		_slot_buttons[i].focus_mode = Control.FOCUS_NONE
	for btn in _ring_buttons:
		btn.disabled = true
	for btn in _bag_buttons:
		btn.disabled = true
	for btn in _prep_buttons:
		btn.disabled = true
	# Drop focus from the just-clicked bag button so ui_left/ui_right reach _unhandled_input
	# instead of navigating UI focus.
	get_viewport().gui_release_focus()
	_highlight_slot_choice()


func _highlight_slot_choice() -> void:
	var current: Enums.Slot = _slot_choice_candidates[_slot_choice_index]
	for i in _slot_buttons.size():
		_slot_buttons[i].modulate = _SLOT_HIGHLIGHT if i == current else Color.WHITE


func _cycle_slot_choice(direction: int) -> void:
	var count := _slot_choice_candidates.size()
	_slot_choice_index = (_slot_choice_index + direction) % count
	if _slot_choice_index < 0:
		_slot_choice_index += count
	_highlight_slot_choice()


func _confirm_slot_choice() -> void:
	var data := _selecting_hand_data
	var chosen: Enums.Slot = _slot_choice_candidates[_slot_choice_index]
	_end_slot_selection()
	_inventory.remove_from_bag(data)
	_inventory.equip(chosen, data)


func _cancel_slot_choice() -> void:
	# The item was never removed from the bag, so cancelling just clears the prompt.
	_end_slot_selection()


func _end_slot_selection() -> void:
	_selecting_hand_data = null
	_slot_choice_candidates = []
	_slot_choice_index = 0
	for btn in _slot_buttons:
		btn.modulate = Color.WHITE
		btn.focus_mode = Control.FOCUS_ALL
	# Restore correct disabled state (honors _can_equip/_dungeon_locked and empty bag slots).
	_apply_equip_state()
	_refresh_bag()


func _unhandled_input(event: InputEvent) -> void:
	if _selecting_hand_data == null:
		return
	if event.is_action_pressed("ui_cancel"):
		_cancel_slot_choice()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("attack"):
		_confirm_slot_choice()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_cycle_slot_choice(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_cycle_slot_choice(-1)
		get_viewport().set_input_as_handled()


# --- Spell Prep ---

func setup_spell_prep(player: Player) -> void:
	_player = player
	_player.prep_slots_changed.connect(_on_prep_slots_changed)
	_player.prepared_spells_changed.connect(func(_s: Array) -> void: _rebuild_prep_ui())
	_rebuild_prep_ui()


func _on_prep_slots_changed(_size: int) -> void:
	_rebuild_prep_ui()


func _rebuild_prep_ui() -> void:
	if _player == null:
		return
	if _prep_container == null:
		_prep_container = VBoxContainer.new()
		_prep_container.name = "PrepContainer"
		var lbl := Label.new()
		lbl.text = "Prepared Spells"
		_prep_container.add_child(lbl)
		$HBoxContainer/PanelContainer/VBoxContainer.add_child(_prep_container)
	for btn in _prep_buttons:
		btn.queue_free()
	_prep_buttons.clear()
	for i in _player.prep_slots:
		var prepared := _player.get_prepared_spells()
		var spell: SpellData = prepared[i] if i < prepared.size() else null
		var btn := Button.new()
		btn.text = spell.display_name if spell != null else "—"
		btn.disabled = _dungeon_locked
		btn.pressed.connect(_on_prep_button_pressed.bind(i))
		_prep_container.add_child(btn)
		_prep_buttons.append(btn)


func _on_prep_button_pressed(index: int) -> void:
	if _player == null or _dungeon_locked:
		return
	var prepared := _player.get_prepared_spells()
	var current: SpellData = prepared[index] if index < prepared.size() else null
	var learned := _player.get_learned_spells()
	var unprepared: Array[SpellData] = []
	for spell in learned:
		if not prepared.has(spell):
			unprepared.append(spell)
	if current != null:
		_player.unprepare_spell(index)
		return
	if unprepared.is_empty():
		return
	_player.prepare_spell(unprepared[0], index)


# --- Detail Panel ---

func _on_slot_button_hovered(slot: Enums.Slot) -> void:
	if _inventory == null:
		return
	_show_detail(_inventory.get_equipped(slot))


func _on_ring_button_hovered(index: int) -> void:
	if _inventory == null:
		return
	var rings := _inventory.get_rings()
	_show_detail(rings[index] if index < rings.size() else null)


func _on_bag_button_hovered(index: int) -> void:
	if _inventory == null:
		return
	var bag := _inventory.get_bag()
	_show_detail(bag[index] if index < bag.size() else null)


func _show_detail(data: EquipmentData) -> void:
	if data == null:
		_hide_detail()
		return
	_detail_name_label.text = data.item_name
	if data is TomeData:
		var tome := data as TomeData
		var spell_name := tome.spell.display_name if tome.spell != null else "???"
		_detail_stats_label.text = "Teaches: %s" % spell_name
		return
	var stats_text := _format_stat_modifiers(data.stat_modifiers)
	if data.spell_cost_multiplier != 1.0:
		var pct := int(round((1.0 - data.spell_cost_multiplier) * 100.0))
		stats_text += "\n-%d%% Spell Cost" % pct
	_detail_stats_label.text = stats_text


# The panel stays visible so its reserved width never collapses; clearing the labels
# empties it without reflowing the rest of the inventory row (which caused a hover flicker
# loop when the panel expanded, shifted a button out from under the cursor, then contracted).
func _hide_detail() -> void:
	_detail_name_label.text = ""
	_detail_stats_label.text = ""


func _format_stat_modifiers(modifiers: Dictionary) -> String:
	if modifiers.is_empty():
		return ""
	var stat_names := Enums.Stat.keys()
	var lines: Array[String] = []
	for stat_key in modifiers:
		var value: float = modifiers[stat_key]
		var name: String = stat_names[stat_key] if stat_key < stat_names.size() else str(stat_key)
		var sign: String = "+" if value >= 0.0 else ""
		var formatted_value: String = str(int(value)) if value == floorf(value) else "%.1f" % value
		lines.append(sign + formatted_value + " " + name)
	return "\n".join(lines)
