## Headless I/O script: read a .tres file and emit its content as JSON on stdout.
##
## Usage (from project root):
##   godot --headless --path . --script res://tools/content_editor/godot/io_read.gd -- res://path/to/file.tres
##
## JSON format:
##   Top-level resource → { "_godot_meta": { class, script, uid, path, inline }, <prop>: <value>, ... }
##   External resource ref → { "__ref": "res://...", "__uid": "uid://..." }
##   Inline sub-resource  → { "_godot_meta": { ..., inline: true }, <prop>: <value>, ... }
##   StringName value     → { "__sn": "the_name" }
##   Dictionary (int keys) → { "__key_type": "int", "0": ..., "1": ... }
##   Dictionary (StringName keys) → { "__key_type": "StringName", "key": ... }
extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: io_read.gd -- <res://path/to/resource.tres>")
		quit(1)
		return

	var path := args[0]
	var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null:
		printerr("io_read: failed to load: " + path)
		quit(1)
		return

	var data := _serialize_resource(resource, path)
	print(JSON.stringify(data, "\t"))
	quit(0)


func _serialize_resource(resource: Resource, path: String = "") -> Dictionary:
	var data: Dictionary = {}

	var meta: Dictionary = {}
	var s: Script = resource.get_script() as Script
	if s != null:
		meta["script"] = s.resource_path
		var gname: StringName = s.get_global_name()
		if gname != &"":
			meta["class"] = str(gname)

	var is_inline := path == ""
	meta["inline"] = is_inline
	if not is_inline:
		meta["path"] = path
		var uid_int := ResourceLoader.get_resource_uid(path)
		if uid_int != ResourceUID.INVALID_ID:
			meta["uid"] = ResourceUID.id_to_text(uid_int)

	data["_godot_meta"] = meta

	for prop in resource.get_property_list():
		if not (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var pname: String = prop["name"]
		data[pname] = _serialize_value(resource.get(pname))

	return data


func _serialize_value(value: Variant) -> Variant:
	if value == null:
		return null

	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return value
		TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return {"__sn": str(value)}
		TYPE_ARRAY:
			var arr: Array = []
			for item in value:
				arr.append(_serialize_value(item))
			return arr
		TYPE_DICTIONARY:
			var key_type := _detect_key_type(value)
			var d: Dictionary = {}
			if key_type != "":
				d["__key_type"] = key_type
			for k in value:
				d[str(k)] = _serialize_value(value[k])
			return d
		TYPE_OBJECT:
			if value is Resource:
				var res := value as Resource
				var res_path := res.resource_path
				# Sub-resources within a .tres have paths like "res://file.tres::SubId"
				# They are inline, not separate files — check for the "::" marker.
				var is_sub_resource := "::" in res_path
				if res_path != "" and not is_sub_resource:
					# External standalone resource — store as a ref
					var uid_int := ResourceLoader.get_resource_uid(res_path)
					var ref: Dictionary = {"__ref": res_path}
					if uid_int != ResourceUID.INVALID_ID:
						ref["__uid"] = ResourceUID.id_to_text(uid_int)
					return ref
				else:
					# Inline sub-resource (empty path or sub-resource path) — recurse
					return _serialize_resource(res)
			return null
		_:
			return null


func _detect_key_type(d: Dictionary) -> String:
	for k in d:
		match typeof(k):
			TYPE_INT: return "int"
			TYPE_STRING_NAME: return "StringName"
			TYPE_STRING: return "String"
			_: return "variant"
	return ""
