class_name FloorSlot
extends Resource

enum SlotType { FIXED = 0, RANDOM_TYPE = 1, WEIGHTED = 2 }

# Select which kind of slot this is.
@export var type: SlotType = SlotType.FIXED

# FIXED: specific event wrapper (CombatEventData, BossEventData, etc.)
@export var event: Resource

# RANDOM_TYPE: pick a random event of this type from the pool.
@export_enum("combat", "boss", "dialogue", "skill_check", "rest") var event_type: int = 0

# WEIGHTED: weighted pool of events or types.
@export var entries: Array = []


const TYPE_NAMES := ["combat", "boss", "dialogue", "skill_check", "rest"]


func resolve(rng: RandomNumberGenerator, pool) -> Dictionary:
	match type:
		SlotType.FIXED:       return _resolve_fixed(pool)
		SlotType.RANDOM_TYPE: return _resolve_random(rng, pool)
		SlotType.WEIGHTED:    return _resolve_weighted(rng, pool)
	push_error("[FloorSlot] Unknown slot type %d" % type)
	return {}


func _resolve_fixed(pool) -> Dictionary:
	if event == null:
		push_warning("[FloorSlot] FIXED slot has no event — skipping")
		return {}
	return pool.event_config_for(event)


func _resolve_random(rng: RandomNumberGenerator, pool) -> Dictionary:
	var type_str: String = TYPE_NAMES[event_type]
	var wrapper = pool.pick_of_type(type_str, rng)
	if wrapper == null:
		push_warning("[FloorSlot] No events of type '%s' in pool — skipping" % type_str)
		return {}
	return pool.event_config_for(wrapper)


func _resolve_weighted(rng: RandomNumberGenerator, pool) -> Dictionary:
	if entries.is_empty():
		push_warning("[FloorSlot] WEIGHTED slot has no entries — skipping")
		return {}

	var total_weight := 0
	for entry in entries:
		total_weight += max(entry.weight, 1)

	var roll := rng.randi() % total_weight
	for entry in entries:
		roll -= max(entry.weight, 1)
		if roll < 0:
			if entry.event != null:
				return pool.event_config_for(entry.event)
			var type_str: String = TYPE_NAMES[entry.event_type]
			var wrapper = pool.pick_of_type(type_str, rng)
			if wrapper == null:
				push_warning("[FloorSlot] No events of type '%s' — skipping entry" % type_str)
				return {}
			return pool.event_config_for(wrapper)

	push_warning("[FloorSlot] Weighted roll fell through — using first entry")
	var first = entries[0]
	if first.event != null:
		return pool.event_config_for(first.event)
	var type_str: String = TYPE_NAMES[first.event_type]
	var wrapper = pool.pick_of_type(type_str, rng)
	return pool.event_config_for(wrapper) if wrapper != null else {}
