class_name DialogueLoader

## Loads a dialogue Dictionary from either a .tres path (DialogueData resource)
## or a legacy .json path. Returns {} on any failure.

static func load_dict(path: String) -> Dictionary:
	if path == "":
		return {}
	if path.ends_with(".tres"):
		var res := load(path) as DialogueData
		if res == null:
			push_warning("DialogueLoader: could not load DialogueData at '%s'" % path)
			return {}
		return _read_json(res.dialogue_path)
	return _read_json(path)


static func _read_json(json_path: String) -> Dictionary:
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_warning("DialogueLoader: could not open '%s'" % json_path)
		return {}
	var result = JSON.parse_string(file.get_as_text())
	if not result is Dictionary:
		push_warning("DialogueLoader: invalid JSON at '%s'" % json_path)
		return {}
	return result
