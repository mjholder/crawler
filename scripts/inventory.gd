class_name Inventory
extends Node

# --- Signals ---
signal slot_changed(slot: Enums.Slot, new_data: EquipmentData, old_data: EquipmentData)
signal ring_changed(index: int, new_data: EquipmentData, old_data: EquipmentData)
signal bag_changed()
signal consumable_belt_changed(index: int, new_data: ConsumableData, old_data: ConsumableData)
signal belt_size_changed(new_size: int)

# --- Config ---
@export var max_bag_size: int = 15
@export var max_rings: int = 2
@export var belt_size: int = 2

# --- State ---
var _equipped: Dictionary = {}       # Enums.Slot -> EquipmentData
var _rings: Array = []               # Array of EquipmentData or null, length = max_rings
var _consumable_belt: Array = []     # Array of ConsumableData or null, length = belt_size
var _bag: Array[EquipmentData] = []
var _dungeon_locked: bool = false    # true while inside a dungeon; blocks equip/unequip/remove_from_bag


func _ready() -> void:
	_rings.resize(max_rings)
	_rings.fill(null)
	_consumable_belt.resize(belt_size)
	_consumable_belt.fill(null)


# --- Dungeon Lock ---

func set_dungeon_locked(locked: bool) -> void:
	_dungeon_locked = locked


func is_dungeon_locked() -> bool:
	return _dungeon_locked


# --- Named Slot API ---

func equip(slot: Enums.Slot, data: EquipmentData) -> void:
	if _dungeon_locked:
		return
	var old: EquipmentData = _equipped.get(slot, null)
	if old != null:
		add_to_bag(old)
	_equipped[slot] = data
	slot_changed.emit(slot, data, old)


func unequip(slot: Enums.Slot) -> void:
	if _dungeon_locked:
		return
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
	if _dungeon_locked:
		return false
	for i in range(_rings.size()):
		if _rings[i] == null:
			_rings[i] = data
			ring_changed.emit(i, data, null)
			return true
	return false


func equip_ring_at(index: int, data: EquipmentData) -> void:
	if _dungeon_locked:
		return
	if index < 0 or index >= _rings.size():
		return
	var old = _rings[index]
	_rings[index] = data
	if old != null:
		add_to_bag(old)
	ring_changed.emit(index, data, old)


func unequip_ring(index: int) -> void:
	if _dungeon_locked:
		return
	if index < 0 or index >= _rings.size() or _rings[index] == null:
		return
	var old = _rings[index]
	_rings[index] = null
	add_to_bag(old)
	ring_changed.emit(index, null, old)


func get_rings() -> Array:
	return _rings.duplicate()


# --- Consumable Belt API ---

func equip_consumable(data: ConsumableData) -> bool:
	if _dungeon_locked:
		return false
	for i in range(_consumable_belt.size()):
		if _consumable_belt[i] == null:
			_consumable_belt[i] = data
			consumable_belt_changed.emit(i, data, null)
			return true
	return false


func equip_consumable_at(index: int, data: ConsumableData) -> void:
	if _dungeon_locked:
		return
	if index < 0 or index >= _consumable_belt.size():
		return
	var old: ConsumableData = _consumable_belt[index]
	if old != null:
		add_to_bag(old)
	_consumable_belt[index] = data
	consumable_belt_changed.emit(index, data, old)


func unequip_consumable(index: int) -> void:
	if _dungeon_locked:
		return
	if index < 0 or index >= _consumable_belt.size() or _consumable_belt[index] == null:
		return
	var old: ConsumableData = _consumable_belt[index]
	_consumable_belt[index] = null
	add_to_bag(old)
	consumable_belt_changed.emit(index, null, old)


func consume(index: int) -> ConsumableData:
	# Bypasses dungeon lock — consuming always works during a dungeon
	if index < 0 or index >= _consumable_belt.size():
		return null
	var old: ConsumableData = _consumable_belt[index]
	if old == null:
		return null
	_consumable_belt[index] = null
	consumable_belt_changed.emit(index, null, old)
	return old


func get_consumable_at(index: int) -> ConsumableData:
	if index < 0 or index >= _consumable_belt.size():
		return null
	return _consumable_belt[index]


func get_consumable_belt() -> Array:
	return _consumable_belt.duplicate()


func set_belt_size(n: int) -> void:
	var old_size := _consumable_belt.size()
	if n == old_size:
		return
	if n < old_size:
		for i in range(n, old_size):
			if _consumable_belt[i] != null:
				add_to_bag(_consumable_belt[i])
	_consumable_belt.resize(n)
	belt_size_changed.emit(n)


func place_consumable_on_belt(index: int, data: ConsumableData) -> ConsumableData:
	# Bypasses dungeon lock — item is in-hand from pickup, not coming from the bag.
	# Returns the displaced item (or null if slot was empty).
	if index < 0 or index >= _consumable_belt.size():
		return data
	var displaced: ConsumableData = _consumable_belt[index]
	_consumable_belt[index] = data
	consumable_belt_changed.emit(index, data, displaced)
	return displaced


# --- Bag API ---

func add_to_bag(data: EquipmentData) -> bool:
	if _bag.size() >= max_bag_size:
		return false
	_bag.append(data)
	bag_changed.emit()
	return true


func remove_from_bag(data: EquipmentData) -> void:
	if _dungeon_locked:
		return
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

func clear() -> void:
	_equipped.clear()
	_rings.fill(null)
	_consumable_belt.fill(null)
	_bag.clear()


func get_all_equipped() -> Array[EquipmentData]:
	# Excludes consumables — they grant active effects, not passive stat modifiers
	var result: Array[EquipmentData] = []
	for data in _equipped.values():
		result.append(data)
	for ring in _rings:
		if ring != null:
			result.append(ring)
	return result
