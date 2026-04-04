class_name Inventory
extends Node

# --- Signals ---
signal slot_changed(slot: Enums.Slot, new_data: EquipmentData, old_data: EquipmentData)
signal ring_changed(index: int, new_data: EquipmentData, old_data: EquipmentData)
signal bag_changed()

# --- Config ---
@export var max_bag_size: int = 20
@export var max_rings: int = 2

# --- State ---
var _equipped: Dictionary = {}       # Enums.Slot -> EquipmentData
var _rings: Array = []               # Array of EquipmentData or null, length = max_rings
var _bag: Array[EquipmentData] = []


func _ready() -> void:
	_rings.resize(max_rings)
	_rings.fill(null)


# --- Named Slot API ---

func equip(slot: Enums.Slot, data: EquipmentData) -> void:
	var old: EquipmentData = _equipped.get(slot, null)
	if old != null:
		add_to_bag(old)
	_equipped[slot] = data
	slot_changed.emit(slot, data, old)


func unequip(slot: Enums.Slot) -> void:
	if not _equipped.has(slot):
		return
	var old: EquipmentData = _equipped[slot]
	_equipped.erase(slot)
	add_to_bag(old)
	slot_changed.emit(slot, null, old)


func get_equipped(slot: Enums.Slot) -> EquipmentData:
	return _equipped.get(slot, null)


# --- Ring API ---

func equip_ring(data: EquipmentData) -> bool:
	for i in range(_rings.size()):
		if _rings[i] == null:
			_rings[i] = data
			ring_changed.emit(i, data, null)
			return true
	return false


func equip_ring_at(index: int, data: EquipmentData) -> void:
	if index < 0 or index >= _rings.size():
		return
	var old = _rings[index]
	_rings[index] = data
	if old != null:
		add_to_bag(old)
	ring_changed.emit(index, data, old)


func unequip_ring(index: int) -> void:
	if index < 0 or index >= _rings.size() or _rings[index] == null:
		return
	var old = _rings[index]
	_rings[index] = null
	add_to_bag(old)
	ring_changed.emit(index, null, old)


func get_rings() -> Array:
	return _rings.duplicate()


# --- Bag API ---

func add_to_bag(data: EquipmentData) -> bool:
	if _bag.size() >= max_bag_size:
		return false
	_bag.append(data)
	bag_changed.emit()
	return true


func remove_from_bag(data: EquipmentData) -> void:
	var index := _bag.find(data)
	if index == -1:
		return
	_bag.remove_at(index)
	bag_changed.emit()


func is_bag_full() -> bool:
	return _bag.size() >= max_bag_size


func get_bag() -> Array[EquipmentData]:
	return _bag.duplicate()


# --- Utility ---

func get_all_equipped() -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	for data in _equipped.values():
		result.append(data)
	for ring in _rings:
		if ring != null:
			result.append(ring)
	return result
