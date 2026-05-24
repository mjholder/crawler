class_name FloorEventPool

const TYPE_SCENE_PATHS := {
	"combat":      "res://scenes/combat_event.tscn",
	"boss":        "res://scenes/boss_event.tscn",
	"dialogue":    "res://scenes/dialogue_event.tscn",
	"skill_check": "res://scenes/skill_check_event.tscn",
	"rest":        "res://scenes/rest_event.tscn",
}

const EVENT_DIRS := {
	"combat":      "res://resources/events/combat/",
	"boss":        "res://resources/events/boss/",
	"dialogue":    "res://resources/events/dialogue/",
	"skill_check": "res://resources/events/skill_check/",
	"rest":        "res://resources/events/rest/",
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


func filter_by_tags(tags: Array[String]) -> Array:
	var result: Array = []
	for floor in _floors:
		var matches := true
		for tag in tags:
			if tag not in floor.tags:
				matches = false
				break
		if matches:
			result.append(floor)
	return result


func pick_of_type(type: String, rng: RandomNumberGenerator) -> Resource:
	var options: Array = _events_by_type.get(type, [])
	if options.is_empty():
		return null
	return options[rng.randi() % options.size()]


func event_config_for(wrapper: Resource) -> Dictionary:
	var type := _type_for_wrapper(wrapper)
	var scene: PackedScene = _scenes.get(type)
	if scene == null:
		push_warning("[FloorEventPool] No scene for event type '%s'" % type)
		return {}
	var data := _load_json(wrapper.get("event_path") as String)
	return {"scene": scene, "data": data}


func _type_for_wrapper(wrapper: Resource) -> String:
	if wrapper is CombatEventData:     return "combat"
	if wrapper is BossEventData:       return "boss"
	if wrapper is DialogueEventData:   return "dialogue"
	if wrapper is SkillCheckEventData: return "skill_check"
	if wrapper is RestEventData:       return "rest"
	return ""


func _load_json(path: String) -> Dictionary:
	if path == "":
		push_warning("[FloorEventPool] _load_json called with empty path")
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_warning("[FloorEventPool] Could not read '%s'" % path)
		return {}
	return JSON.parse_string(text)
