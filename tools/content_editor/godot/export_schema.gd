## Headless schema export: introspects resource classes and emits schema JSON on stdout.
##
## Usage (from project root):
##   godot --headless --path . --script res://tools/content_editor/godot/export_schema.gd
##
## The sidecar runs this once on startup (or on demand) and caches the result as schema.json.
## Re-run after adding/changing @export properties in any resource script.
extends SceneTree

# All resource scripts whose classes should appear in the schema.
# Order matters for inheritance resolution: bases before derived.
const RESOURCE_SCRIPTS: Array[String] = [
	"res://scripts/enums.gd",
	"res://scripts/effect.gd",
	"res://scripts/damage_effect.gd",
	"res://scripts/heal_effect.gd",
	"res://scripts/buff_effect.gd",
	"res://scripts/status_effect.gd",
	"res://scripts/equipment_data.gd",
	"res://scripts/weapon_data.gd",
	"res://scripts/consumable_data.gd",
	"res://scripts/attack_data.gd",
	"res://scripts/shop_data.gd",
	"res://scripts/player_class_data.gd",
	"res://scripts/proc_def.gd",
	"res://scripts/conditional_modifier.gd",
	"res://scripts/status_data.gd",
	"res://scripts/blessing_data.gd",
	"res://scripts/spell_data.gd",
	"res://scripts/tome_data.gd",
	"res://scripts/dialogue_data.gd",
	"res://scripts/combat_event_data.gd",
	"res://scripts/boss_event_data.gd",
	"res://scripts/dialogue_event_data.gd",
	"res://scripts/skill_check_event_data.gd",
	"res://scripts/rest_event_data.gd",
	"res://scripts/floor_slot.gd",
	"res://scripts/weighted_entry.gd",
	"res://scripts/dungeon_floor_data.gd",
]

# Scripts whose class-level constants contain enum declarations.
const ENUM_SCRIPTS: Array[String] = [
	"res://scripts/enums.gd",
	"res://scripts/attack_data.gd",
	"res://scripts/consumable_data.gd",
	"res://scripts/status_data.gd",
]


func _init() -> void:
	var schema := _build_schema()
	print(JSON.stringify(schema, "\t"))
	quit(0)


func _build_schema() -> Dictionary:
	var schema: Dictionary = {"classes": {}, "enums": {}}

	# --- Collect enums ---
	for script_path in ENUM_SCRIPTS:
		var s := load(script_path) as Script
		if s == null:
			continue
		var class_prefix: String = str(s.get_global_name())
		for k in s.get_script_constant_map():
			var v = s.get_script_constant_map()[k]
			if v is Dictionary and not v.is_empty():
				schema["enums"][class_prefix + "." + k] = v

	# --- Load annotations for untyped fields ---
	var annotations: Dictionary = {}
	var ann_path := "res://tools/content_editor/godot/annotations.json"
	if FileAccess.file_exists(ann_path):
		var f := FileAccess.open(ann_path, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			annotations = parsed

	# --- Introspect each resource class ---
	for script_path in RESOURCE_SCRIPTS:
		var s := load(script_path) as Script
		if s == null:
			continue
		var class_name_str := str(s.get_global_name())
		if class_name_str == "" or class_name_str == "Enums":
			continue

		# Determine parent class name
		var parent := ""
		var base: Script = s.get_base_script() as Script
		if base != null:
			var base_name := str(base.get_global_name())
			if base_name != "":
				parent = base_name

		# Instantiate to get the full property list
		var instance: Resource = s.new()
		# Merge annotations from the full inheritance chain (derived first; parent fills gaps)
		var merged_annotations: Dictionary = {}
		var walk_script: Script = s
		while walk_script != null:
			var walk_name := str(walk_script.get_global_name())
			var walk_ann: Dictionary = annotations.get(walk_name, {})
			for k in walk_ann:
				if not merged_annotations.has(k):
					merged_annotations[k] = walk_ann[k]
			walk_script = walk_script.get_base_script() as Script
		var class_annotations: Dictionary = merged_annotations
		var properties: Array = []

		for prop in instance.get_property_list():
			if not (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			properties.append(_describe_property(prop, class_annotations, schema["enums"]))

		schema["classes"][class_name_str] = {
			"script": script_path,
			"extends": parent,
			"properties": properties,
		}

	return schema


func _describe_property(prop: Dictionary, class_annotations: Dictionary, enums: Dictionary) -> Dictionary:
	var p: Dictionary = {"name": prop["name"]}
	var ann: Dictionary = class_annotations.get(prop["name"], {})

	match prop["type"]:
		TYPE_BOOL:
			p["type"] = "bool"

		TYPE_INT:
			if prop["hint"] == PROPERTY_HINT_ENUM:
				p["type"] = "enum"
				# Try to find the matching enum definition by hint_string label
				var resolved_enum := _find_enum_by_hint(prop["hint_string"], enums)
				if resolved_enum != "":
					p["enum_ref"] = resolved_enum
				else:
					# Inline enum values from hint_string "NAME:0,NAME2:1,..." or "NAME,NAME2,..."
					p["enum_values"] = _parse_enum_hint(prop["hint_string"])
			else:
				p["type"] = "int"

		TYPE_FLOAT:
			p["type"] = "float"

		TYPE_STRING:
			p["type"] = "String"

		TYPE_STRING_NAME:
			p["type"] = "StringName"

		TYPE_ARRAY:
			p["type"] = "Array"
			var element_type: String = ann.get("element_type", "")
			if element_type == "" and prop["hint_string"] != "":
				# hint_string format: "type_id/hint_id:ClassName"
				var parts: PackedStringArray = (prop["hint_string"] as String).split(":")
				if parts.size() > 1 and parts[1] != "" and parts[1] != "Resource":
					element_type = parts[1]
			p["element_type"] = element_type

		TYPE_DICTIONARY:
			p["type"] = "Dictionary"
			p["key_type"] = ann.get("key_type", "")
			p["value_type"] = ann.get("value_type", "")

		TYPE_OBJECT:
			if prop["hint"] == PROPERTY_HINT_RESOURCE_TYPE:
				p["type"] = "Resource"
				p["resource_type"] = prop["hint_string"]
				var ann_type: String = ann.get("resource_type", "")
				if ann_type != "":
					p["resource_type"] = ann_type
			else:
				p["type"] = "Object"

		_:
			p["type"] = "unknown"

	return p


func _find_enum_by_hint(hint_string: String, enums: Dictionary) -> String:
	# Godot encodes enum hints as "VALUE:int,VALUE2:int2,..." or just "VALUE,VALUE2,...".
	# We try to match the set of names against a known enum.
	var hint_names: Array[String] = []
	for entry in hint_string.split(","):
		hint_names.append(entry.split(":")[0].strip_edges())

	for enum_name in enums:
		var enum_dict: Dictionary = enums[enum_name]
		if enum_dict.keys().size() == hint_names.size():
			var match_all := true
			for name in hint_names:
				if not enum_dict.has(name):
					match_all = false
					break
			if match_all:
				return enum_name
	return ""


func _parse_enum_hint(hint_string: String) -> Dictionary:
	var result: Dictionary = {}
	var idx := 0
	for entry in hint_string.split(","):
		var parts := entry.split(":")
		var name := parts[0].strip_edges()
		var value := int(parts[1]) if parts.size() > 1 else idx
		result[name] = value
		idx += 1
	return result
