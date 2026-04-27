class_name InventoryPanel
extends Control

# --- Node References ---

@onready var _paper_doll: PaperDoll = get_node_or_null("HBoxContainer/PaperDollPanel/PaperDoll")
@onready var _equipped_slots: VBoxContainer = $HBoxContainer/PanelContainer/VBoxContainer/EquippedSlots
@onready var _bag_grid: GridContainer = $HBoxContainer/PanelContainer/VBoxContainer/BagGrid
@onready var _detail_panel: PanelContainer = $HBoxContainer/DetailPanel
@onready var _detail_name_label: Label = $HBoxContainer/DetailPanel/VBoxContainer/DetailNameLabel
@onready var _detail_stats_label: Label = $HBoxContainer/DetailPanel/VBoxContainer/DetailStatsLabel

# --- Constants ---

# Names match Enums.Slot definition order: WEAPON, HANDS, FEET, LEGS, TORSO, HEAD
const _SLOT_CONTAINER_NAMES: Array[String] = [
	"WeaponEquipment", "HandsEquipment", "FeetEquipment",
	"LegsEquipment", "TorsoEquipment", "HeadEquipment"
]
const _RING_CONTAINER_NAMES: Array[String] = ["RingEquipment1", "RingEquipment2"]

# --- State ---

var _inventory: Inventory
var _slot_buttons: Array[Button] = []
var _ring_buttons: Array[Button] = []
var _bag_buttons: Array[Button] = []
var _can_equip: bool = true
var _dungeon_locked: bool = false


func _ready() -> void:
	_collect_node_refs()
	_connect_buttons()


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
	_inventory.remove_from_bag(data)
	if data is ConsumableData:
		if not _inventory.equip_consumable(data as ConsumableData):
			_inventory.add_to_bag(data)
	elif data.is_ring:
		_inventory.equip_ring(data)
	else:
		_inventory.equip(data.slot, data)


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
	_detail_stats_label.text = _format_stat_modifiers(data.stat_modifiers)
	_detail_panel.show()


func _hide_detail() -> void:
	_detail_panel.hide()


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
