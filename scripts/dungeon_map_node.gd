class_name DungeonMapNode
extends WorldMapNode

# --- Floor Config ---

# Set a specific floor for this node. Takes precedence over floor_tags.
@export var floor: DungeonFloorData = null

# If floor is null, pick at random from all floors matching ALL of these tags.
# If also empty (0), pick from the full pool. Bitmask — see Enums.FloorTag.
@export_flags("Short:1", "Medium:2", "Mixed:4", "Demo:8") var floor_tags: int = 0

# Resolved at world-map load by WorldMap._ready() — do not set manually.
var _resolved_event_configs: Array[Dictionary] = []


# --- Called by WorldMap during floor resolution ---

func resolve_floor(rng: RandomNumberGenerator, pool: FloorEventPool) -> void:
	var resolved_floor: DungeonFloorData

	if floor != null:
		resolved_floor = floor
	else:
		var candidates := (
			pool.filter_by_tags(floor_tags) if floor_tags != 0
			else pool.all_floors()
		)
		if candidates.is_empty():
			push_warning("[DungeonMapNode '%s'] No floors match constraint (tags=%s) — node will produce no events" % [name, floor_tags])
			return
		resolved_floor = candidates[rng.randi() % candidates.size()]

	_resolved_event_configs.clear()
	for slot in resolved_floor.slots:
		var config: Dictionary = slot.resolve(rng, pool)
		if not config.is_empty():
			_resolved_event_configs.append(config)


# --- Event Generation ---

func generate_event_configs() -> Array[Dictionary]:
	if _resolved_event_configs.is_empty():
		push_warning("[DungeonMapNode '%s'] generate_event_configs() called with no resolved events — was resolve_floor() called?" % name)
	return _resolved_event_configs
