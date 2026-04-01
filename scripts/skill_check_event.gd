class_name SkillCheckEvent
extends Event

# --- Signals ---

signal skill_check_requested(stat: Enums.Stat, label: String)
signal dialogue_requested(data: Dictionary)

# --- Data ---

@export var event_json_path: String = ""

var _stat: Enums.Stat
var _label: String
var _on_success_path: String
var _on_failure_path: String
var _success: bool

# --- Phase Hooks ---

func _on_setup() -> void:
	if event_json_path == "":
		push_warning("SkillCheckEvent: event_json_path not set")
		return
	var event_file := FileAccess.open(event_json_path, FileAccess.READ)
	if event_file == null:
		push_warning("SkillCheckEvent: could not open '%s'" % event_json_path)
		return
	var data: Dictionary = JSON.parse_string(event_file.get_as_text())
	rewards = data.get("rewards", {})
	_label = data.get("label", "")
	_on_success_path = data.get("on_success", "")
	_on_failure_path = data.get("on_failure", "")
	var stat_key: String = data.get("stat", "")
	if not stat_key in Enums.Stat:
		push_warning("SkillCheckEvent: unknown stat '%s', defaulting to LUCK" % stat_key)
		_stat = Enums.Stat.LUCK
		return
	_stat = Enums.Stat[stat_key]


func _on_running() -> void:
	skill_check_requested.emit(_stat, _label)


func _on_resolution() -> void:
	var path: String = _on_success_path if _success else _on_failure_path
	if path == "":
		_set_phase(Phase.COMPLETE)
		return
	var dialogue_file := FileAccess.open(path, FileAccess.READ)
	if dialogue_file == null:
		push_warning("SkillCheckEvent: could not open dialogue '%s'" % path)
		_set_phase(Phase.COMPLETE)
		return
	var dialogue_data: Dictionary = JSON.parse_string(dialogue_file.get_as_text())
	dialogue_requested.emit(dialogue_data)


# --- Public API ---

# Called by game.gd when the skill check panel resolves.
func on_skill_check_complete(success: bool) -> void:
	_success = success
	_set_phase(Phase.RESOLUTION)


# Called by game.gd when gui.dialogue_complete fires during RESOLUTION.
func on_dialogue_complete() -> void:
	_set_phase(Phase.COMPLETE)
