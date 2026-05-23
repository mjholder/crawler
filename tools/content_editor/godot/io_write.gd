## Headless I/O script: read a JSON file and write it as a .tres file.
##
## Usage (from project root):
##   godot --headless --path . --script res://tools/content_editor/godot/io_write.gd -- res://path/to/dest.tres /abs/path/to/input.json
##
## The sidecar writes the resource JSON to a temp file, passes the path here,
## and this script deletes the temp file after reading.
##
## If the destination .tres already exists it is loaded first so the UID is
## preserved; otherwise a new resource is created using _godot_meta.script.
extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Usage: io_write.gd -- <res://dest.tres> </abs/path/input.json>")
		quit(1)
		return

	var dest_path := args[0]
	var json_file_path := args[1]

	# Read JSON from the temp file (absolute path, not res://)
	if not FileAccess.file_exists(json_file_path):
		printerr("io_write: json file not found: " + json_file_path)
		quit(1)
		return

	var f := FileAccess.open(json_file_path, FileAccess.READ)
	if f == null:
		printerr("io_write: cannot open: " + json_file_path)
		quit(1)
		return
	var json_text := f.get_as_text()
	f.close()
	# Clean up temp file immediately after reading
	DirAccess.remove_absolute(json_file_path)

	var data = JSON.parse_string(json_text)
	if data == null or not data is Dictionary:
		printerr("io_write: invalid JSON")
		quit(1)
		return

	var resource := _get_or_create_resource(dest_path, data)
	if resource == null:
		printerr("io_write: could not resolve resource type")
		quit(1)
		return

	_apply_data(resource, data)

	var err := ResourceSaver.save(resource, dest_path)
	if err != OK:
		printerr("io_write: ResourceSaver.save failed with error " + str(err))
		quit(1)
		return

	# ResourceSaver in headless mode silently omits the uid= from the
	# [gd_resource] header.  Patch it back so cross-references by UID stay valid.
	_restore_uid_in_header(dest_path)

	quit(0)


func _restore_uid_in_header(path: String) -> void:
	var uid_int := ResourceLoader.get_resource_uid(path)
	if uid_int == ResourceUID.INVALID_ID:
		return

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var content := f.get_as_text()
	f.close()

	var first_newline := content.find("\n")
	if first_newline < 0:
		return
	var header := content.substr(0, first_newline)

	if "uid=" in header:
		return  # already present — nothing to do

	var close_bracket := header.rfind("]")
	if close_bracket < 0:
		return

	var uid_text := ResourceUID.id_to_text(uid_int)
	var patched := header.substr(0, close_bracket) + ' uid="' + uid_text + '"]' + content.substr(first_newline)

	var fw := FileAccess.open(path, FileAccess.WRITE)
	if fw == null:
		return
	fw.store_string(patched)


func _get_or_create_resource(path: String, data: Dictionary) -> Resource:
	# Prefer loading the existing file so the UID is preserved
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)

	# Create a fresh instance from the script declared in _godot_meta
	var meta: Dictionary = data.get("_godot_meta", {})
	var script_path: String = meta.get("script", "")
	if script_path == "":
		return null
	var s = load(script_path)
	if s == null:
		printerr("io_write: cannot load script: " + script_path)
		return null
	return s.new()


func _apply_data(resource: Resource, data: Dictionary) -> void:
	# Build a type-hint map for this resource so we can coerce primitives correctly
	var prop_hints: Dictionary = {}
	for prop in resource.get_property_list():
		prop_hints[prop["name"]] = prop

	for key in data:
		if key.begins_with("_"):
			continue
		var raw = data[key]
		if raw == null:
			continue
		var hint: Dictionary = prop_hints.get(key, {})
		var value = _deserialize_value(raw, hint)
		resource.set(key, value)


func _deserialize_value(raw: Variant, hint: Dictionary) -> Variant:
	if raw == null:
		return null

	# External resource ref
	if raw is Dictionary and raw.has("__ref"):
		var uid_text: String = raw.get("__uid", "")
		var path: String = raw["__ref"]
		if uid_text != "":
			var uid_int := ResourceUID.text_to_id(uid_text)
			if uid_int != ResourceUID.INVALID_ID:
				var uid_path := ResourceUID.get_id_path(uid_int)
				if uid_path != "":
					path = uid_path
		return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)

	# StringName value
	if raw is Dictionary and raw.has("__sn"):
		return StringName(raw["__sn"])

	# Inline sub-resource (has _godot_meta, and inline: true or no path)
	if raw is Dictionary and raw.has("_godot_meta"):
		var meta: Dictionary = raw["_godot_meta"]
		var script_path: String = meta.get("script", "")
		if script_path == "":
			# Built-in engine type (SpriteFrames, AtlasTexture, etc.) that we
			# cannot reconstruct from JSON — return null so _apply_data skips the
			# field, leaving the value from the loaded .tres unchanged.
			return null
		var s = load(script_path)
		if s == null:
			return null
		var sub: Resource = s.new()
		_apply_data(sub, raw)
		return sub

	# Typed-key dictionary
	if raw is Dictionary and raw.has("__key_type"):
		var key_type: String = raw["__key_type"]
		var result: Dictionary = {}
		for k in raw:
			if k == "__key_type":
				continue
			var actual_key: Variant = k
			match key_type:
				"int": actual_key = int(k)
				"StringName": actual_key = StringName(k)
			result[actual_key] = _deserialize_value(raw[k], {})
		return result

	# Plain dictionary without metadata (shouldn't appear in normal round-trips, but handle it)
	if raw is Dictionary:
		var result: Dictionary = {}
		for k in raw:
			result[k] = _deserialize_value(raw[k], {})
		return result

	# Array
	if raw is Array:
		var arr: Array = []
		for item in raw:
			arr.append(_deserialize_value(item, {}))
		return arr

	# Primitives — coerce to the expected GDScript type when we have a hint
	if hint.has("type"):
		match hint["type"]:
			TYPE_BOOL: return bool(raw)
			TYPE_INT: return int(raw)
			TYPE_FLOAT: return float(raw)
			TYPE_STRING: return str(raw)
			TYPE_STRING_NAME: return StringName(str(raw))

	return raw
