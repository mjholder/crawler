class_name InventoryPanel
extends Control

# --- Node References ---

@onready var _equipped_slots: VBoxContainer = $PanelContainer/VBoxContainer/EquippedSlots
@onready var _bag_grid: GridContainer = $PanelContainer/VBoxContainer/BagGrid

# --- State ---

var _inventory: Inventory
var _slot_buttons: Array[Button] = []
var _ring_buttons: Array[Button] = []


func setup(inventory: Inventory) -> void:
	_inventory = inventory
	_build_slot_buttons()
	_inventory.slot_changed.connect(_on_slot_changed)
	_inventory.ring_changed.connect(_on_ring_changed)
	_inventory.bag_changed.connect(_refresh_bag)
	_refresh_slots()
	_refresh_bag()


# --- Build ---

func _build_slot_buttons() -> void:
	var slot_names := Enums.Slot.keys()
	for i in slot_names.size():
		var btn := Button.new()
		btn.pressed.connect(_on_slot_button_pressed.bind(i as Enums.Slot))
		_equipped_slots.add_child(btn)
		_slot_buttons.append(btn)
	for i in _inventory.max_rings:
		var btn := Button.new()
		btn.pressed.connect(_on_ring_button_pressed.bind(i))
		_equipped_slots.add_child(btn)
		_ring_buttons.append(btn)


# --- Refresh ---

func _refresh_slots() -> void:
	var slot_names := Enums.Slot.keys()
	for i in _slot_buttons.size():
		var data: EquipmentData = _inventory.get_equipped(i as Enums.Slot)
		_slot_buttons[i].text = slot_names[i] + ": " + (data.item_name if data else "—")
	var rings := _inventory.get_rings()
	for i in _ring_buttons.size():
		var data: EquipmentData = rings[i]
		_ring_buttons[i].text = "RING %d: " % (i + 1) + (data.item_name if data else "—")


func _refresh_bag() -> void:
	for child in _bag_grid.get_children():
		child.queue_free()
	for data in _inventory.get_bag():
		var btn := Button.new()
		btn.text = data.item_name
		btn.pressed.connect(_on_bag_button_pressed.bind(data))
		_bag_grid.add_child(btn)


# --- Signal Handlers ---

func _on_slot_changed(_slot: Enums.Slot, _new: EquipmentData, _old: EquipmentData) -> void:
	_refresh_slots()


func _on_ring_changed(_index: int, _new: EquipmentData, _old: EquipmentData) -> void:
	_refresh_slots()


# --- Button Handlers ---

func _on_slot_button_pressed(slot: Enums.Slot) -> void:
	if _inventory.get_equipped(slot) != null:
		_inventory.unequip(slot)


func _on_ring_button_pressed(index: int) -> void:
	var rings := _inventory.get_rings()
	if index < rings.size() and rings[index] != null:
		_inventory.unequip_ring(index)


func _on_bag_button_pressed(data: EquipmentData) -> void:
	_inventory.remove_from_bag(data)
	if data.is_ring:
		_inventory.equip_ring(data)
	else:
		_inventory.equip(data.slot, data)
