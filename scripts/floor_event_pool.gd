class_name FloorEventPool

const TYPE_SCENE_PATHS := {
	Enums.EventType.COMBAT:      "res://scenes/combat_event.tscn",
	Enums.EventType.BOSS:        "res://scenes/boss_event.tscn",
	Enums.EventType.DIALOGUE:    "res://scenes/dialogue_event.tscn",
	Enums.EventType.SKILL_CHECK: "res://scenes/skill_check_event.tscn",
	Enums.EventType.REST:        "res://scenes/rest_event.tscn",
}

const EVENT_DIRS := {
	Enums.EventType.COMBAT:      "res://resources/events/combat/",
	Enums.EventType.BOSS:        "res://resources/events/boss/",
	Enums.EventType.DIALOGUE:    "res://resources/events/dialogue/",
	Enums.EventType.SKILL_CHECK: "res://resources/events/skill_check/",
	Enums.EventType.REST:        "res://resources/events/rest/",
}

var _floors: Array = []
var _events_by_type: Dictionary = {}
var _scenes: Dictionary = {}


func build() -> void:
	_floors.clear()
	_events_by_type.clear()
	_scenes.clear()

	for type in TYPE_SCENE_PATHS:
		_scenes[type] = load(TYPE_SCENE_PATHS[type])

	var floor_dir := DirAccess.open("res://resources/dungeon_floors")
	if floor_dir != null:
		floor_dir.list_dir_begin()
		var file := floor_dir.get_next()
		while file != "":
			if file.ends_with(".tres"):
				var r := load("res://resources/dungeon_floors/" + file)
				if r is DungeonFloorData:
					_floors.append(r)
			file = floor_dir.get_next()

	for type in EVENT_DIRS:
		_events_by_type[type] = []
		var edir := DirAccess.open(EVENT_DIRS[type])
		if edir == null:
			continue
		edir.list_dir_begin()
		var efile := edir.get_next()
		while efile != "":
			if efile.ends_with(".tres"):
				var r := load(EVENT_DIRS[type] + efile)
				if r != null and r.get("event_path") != null:
					_events_by_type[type].append(r)
			efile = edir.get_next()


func all_floors() -> Array:
	return _floors


func filter_by_tags(mask: int) -> Array:
	# A floor matches when it carries ALL requested tag bits (AND semantics).
	var result: Array = []
	for floor in _floors:
		if (floor.tags & mask) == mask:
			result.append(floor)
	return result


func pick_of_type(type: Enums.EventType, rng: RandomNumberGenerator) -> Resource:
	var options: Array = _events_by_type.get(type, [])
	if options.is_empty():
		return null
	return options[rng.randi() % options.size()]


func event_config_for(wrapper: Resource) -> Dictionary:
	var type := _type_for_wrapper(wrapper)
	# Boss fights belong to dedicated BossMapNodes, which load the boss directly and
	# bypass this pool entirely. Refuse boss wrappers here so a stray floor slot can
	# never leak a boss into a regular dungeon node's event list.
	if type == Enums.EventType.BOSS:
		push_warning("[FloorEventPool] Boss events are restricted to boss nodes — skipping boss slot")
		return {}
	var scene: PackedScene = _scenes.get(type)
	if scene == null:
		push_warning("[FloorEventPool] No scene for event type %d" % type)
		return {}
	var data := _load_json(wrapper.get("event_path") as String)
	return {"scene": scene, "data": data}


func _type_for_wrapper(wrapper: Resource) -> Enums.EventType:
	if wrapper is CombatEventData:     return Enums.EventType.COMBAT
	if wrapper is BossEventData:       return Enums.EventType.BOSS
	if wrapper is DialogueEventData:   return Enums.EventType.DIALOGUE
	if wrapper is SkillCheckEventData: return Enums.EventType.SKILL_CHECK
	if wrapper is RestEventData:       return Enums.EventType.REST
	return Enums.EventType.COMBAT


func _load_json(path: String) -> Dictionary:
	if path == "":
		push_warning("[FloorEventPool] _load_json called with empty path")
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_warning("[FloorEventPool] Could not read '%s'" % path)
		return {}
	return JSON.parse_string(text)
