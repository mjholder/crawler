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
# Equipped/ring slots hold ItemInstance (base ref + upgrade_level + rarity + tags) so runtime
# investment survives across a run and round-trips through saves. The bag holds bare
# EquipmentData bases — bag items carry no runtime state yet (no loot/smithing UI this pass), and
# equipping one wraps a fresh default instance. Signals and get_equipped()/get_all_equipped()
# still expose bases for back-compat; composition sites use the *_instance() getters.
var _equipped: Dictionary = {}       # Enums.Slot -> ItemInstance
var _rings: Array = []               # Array of ItemInstance or null, length = max_rings
var _consumable_belt: Array = []     # Array of ConsumableData or null, length = belt_size
var _bag: Array[EquipmentData] = []
var _dungeon_locked: bool = false    # true while inside a dungeon; blocks equip/unequip/remove_from_bag
var _slot_locks: Dictionary = {}    # Enums.Slot -> bool; e.g. OFFHAND locked by a two-handed weapon


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


# --- Slot Lock API ---

func lock_slot(slot: Enums.Slot) -> void:
	_slot_locks[slot] = true


func unlock_slot(slot: Enums.Slot) -> void:
	_slot_locks.erase(slot)


func is_slot_locked(slot: Enums.Slot) -> bool:
	return _slot_locks.get(slot, false)


# --- Named Slot API ---

func equip(slot: Enums.Slot, data: EquipmentData) -> void:
	if _dungeon_locked:
		return
	if is_slot_locked(slot):
		return
	var old: ItemInstance = _equipped.get(slot, null)
	if old != null:
		add_to_bag(old.base)
	_equipped[slot] = ItemInstance.wrap(data)
	slot_changed.emit(slot, data, old.base if old != null else null)


func unequip(slot: Enums.Slot) -> void:
	if _dungeon_locked:
		return
	if not _equipped.has(slot):
		return
	var old: ItemInstance = _equipped[slot]
	_equipped.erase(slot)
	add_to_bag(old.base)
	slot_changed.emit(slot, null, old.base)


func get_equipped(slot: Enums.Slot) -> EquipmentData:
	var inst: ItemInstance = _equipped.get(slot, null)
	return inst.base if inst != null else null


## The full ItemInstance in a slot (base + upgrade_level + rarity + tags) — for composition sites
## that need effective power/scaling/modifiers rather than just the base data.
func get_equipped_instance(slot: Enums.Slot) -> ItemInstance:
	return _equipped.get(slot, null)


# --- Ring API ---

func equip_ring(data: EquipmentData) -> bool:
	if _dungeon_locked:
		return false
	for i in range(_rings.size()):
		if _rings[i] == null:
			_rings[i] = ItemInstance.wrap(data)
			ring_changed.emit(i, data, null)
			return true
	return false


func equip_ring_at(index: int, data: EquipmentData) -> void:
	if _dungeon_locked:
		return
	if index < 0 or index >= _rings.size():
		return
	var old: ItemInstance = _rings[index]
	_rings[index] = ItemInstance.wrap(data)
	if old != null:
		add_to_bag(old.base)
	ring_changed.emit(index, data, old.base if old != null else null)


func unequip_ring(index: int) -> void:
	if _dungeon_locked:
		return
	if index < 0 or index >= _rings.size() or _rings[index] == null:
		return
	var old: ItemInstance = _rings[index]
	_rings[index] = null
	add_to_bag(old.base)
	ring_changed.emit(index, null, old.base)


## Ring bases for display (parallels get_equipped). Length = max_rings, null for empty slots.
func get_rings() -> Array:
	var out: Array = []
	for inst in _rings:
		out.append(inst.base if inst != null else null)
	return out


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


# --- Save / Load ---

func to_save_dict() -> Dictionary:
	# Equipped/ring slots serialize the full instance (base path + upgrade_level + rarity + tags);
	# the bag serializes bare base paths. Legacy saves stored plain paths for equipped/rings too —
	# apply_save_dict still reads those (see _instance_from_save).
	var equipped: Dictionary = {}
	for slot in _equipped:
		equipped[slot as int] = _equipped[slot].to_dict()
	var rings: Array = []
	for ring in _rings:
		rings.append(ring.to_dict() if ring != null else {})
	var belt: Array[String] = []
	for item in _consumable_belt:
		belt.append(item.resource_path if item != null else "")
	var bag: Array[String] = []
	for item in _bag:
		bag.append(item.resource_path)
	return {
		"belt_size": _consumable_belt.size(),
		"max_rings": _rings.size(),
		"max_bag_size": max_bag_size,
		"equipped": equipped,
		"rings": rings,
		"consumable_belt": belt,
		"bag": bag,
	}


func apply_save_dict(d: Dictionary) -> void:
	_equipped.clear()
	_rings.fill(null)
	_consumable_belt.fill(null)
	_bag.clear()
	var saved_belt: int = d.get("belt_size", _consumable_belt.size())
	_consumable_belt.resize(saved_belt)
	_consumable_belt.fill(null)
	var saved_rings: int = d.get("max_rings", _rings.size())
	_rings.resize(saved_rings)
	_rings.fill(null)
	for slot_int in d["equipped"]:
		var inst := _instance_from_save(d["equipped"][slot_int])
		if inst != null:
			_equipped[slot_int] = inst
			slot_changed.emit(slot_int, inst.base, null)
	for i in d["rings"].size():
		if i >= _rings.size():
			continue
		var inst := _instance_from_save(d["rings"][i])
		if inst != null:
			_rings[i] = inst
			ring_changed.emit(i, inst.base, null)
	for i in d["consumable_belt"].size():
		var path: String = d["consumable_belt"][i]
		if path.is_empty() or i >= _consumable_belt.size():
			continue
		var data := load(path) as ConsumableData
		if data != null:
			_consumable_belt[i] = data
			consumable_belt_changed.emit(i, data, null)
	for path in d["bag"]:
		if path.is_empty():
			continue
		var data := load(path) as EquipmentData
		if data != null:
			_bag.append(data)
	# Legacy saves stored tomes separately; tomes are now bag items (TomeData extends
	# EquipmentData), so fold any old "tomes" list into the bag.
	for path in d.get("tomes", []):
		if path.is_empty():
			continue
		var data := load(path) as EquipmentData
		if data != null:
			_bag.append(data)
	if not _bag.is_empty():
		bag_changed.emit()


# Rebuilds an equipped/ring ItemInstance from its saved form. New saves store a dict
# (ItemInstance.to_dict); legacy saves stored a bare resource-path string — wrap those as a
# default instance. Empty string / missing base yields null (empty slot).
func _instance_from_save(entry) -> ItemInstance:
	if entry is Dictionary:
		return ItemInstance.from_dict(entry)
	if entry is String:
		if (entry as String).is_empty():
			return null
		var data := load(entry) as EquipmentData
		return ItemInstance.wrap(data) if data != null else null
	return null


# --- Utility ---

func clear() -> void:
	_equipped.clear()
	_rings.fill(null)
	_consumable_belt.fill(null)
	_bag.clear()
	_slot_locks.clear()


func get_all_equipped() -> Array[EquipmentData]:
	# Excludes consumables — they grant active effects, not passive stat modifiers
	var result: Array[EquipmentData] = []
	for inst in _equipped.values():
		result.append(inst.base)
	for ring in _rings:
		if ring != null:
			result.append(ring.base)
	return result


## Every equipped ItemInstance (worn slots + rings), for composition sites that fold effective
## modifiers (get_effective_stat). Excludes consumables, mirroring get_all_equipped().
func get_all_equipped_instances() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for inst in _equipped.values():
		result.append(inst)
	for ring in _rings:
		if ring != null:
			result.append(ring)
	return result
