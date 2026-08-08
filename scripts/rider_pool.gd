class_name RiderPool

## Rider generation source. Scans resources/riders/ and buckets every RiderData by its `rarity`
## metadata, so loot generation can draw a rider from the pool matching an item's rolled rarity and
## attach it (ItemInstance.add_rider). Rarity is a pool tag on the rider, NOT a runtime activation
## gate — once a rider is attached it always applies (see RiderData, ItemInstance.effective_riders).
##
## Mirrors FloorEventPool: build() once, then query. No RNG state of its own — callers pass one.

const RIDER_DIR := "res://resources/riders/"

var _by_rarity: Dictionary = {}  # Enums.Rarity → Array[RiderData]


func build() -> void:
	_by_rarity.clear()
	var dir := DirAccess.open(RIDER_DIR)
	if dir == null:
		push_warning("[RiderPool] Could not open %s" % RIDER_DIR)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var r := load(RIDER_DIR + file)
			if r is RiderData:
				var rider := r as RiderData
				if not _by_rarity.has(rider.rarity):
					_by_rarity[rider.rarity] = []
				_by_rarity[rider.rarity].append(rider)
		file = dir.get_next()


## Every rider tagged with the given rarity (the pool). Empty array if none exist.
func pool_for(rarity: Enums.Rarity) -> Array:
	return _by_rarity.get(rarity, [])


## Draw one rider from the given rarity's pool, or null if that pool is empty.
func pick_of_rarity(rarity: Enums.Rarity, rng: RandomNumberGenerator) -> RiderData:
	var options: Array = pool_for(rarity)
	if options.is_empty():
		return null
	return options[rng.randi() % options.size()]
