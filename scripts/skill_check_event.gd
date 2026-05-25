class_name SkillCheckEvent
extends Event

# --- Signals ---

signal skill_check_requested(stat: Enums.Stat, label: String, threshold_expression: String)
signal dialogue_requested(data: Dictionary)

# --- Data ---

var _stat: Enums.Stat
var _label: String
var _threshold_expression: String
var _on_success_path: String
var _on_failure_path: String
var _rewards_on_success: Dictionary
var _rewards_on_failure: Dictionary
var _success: bool

# --- Public API ---

func initialize(data: Dictionary) -> void:
	_label = data.get("label", "")
	_threshold_expression = data.get("threshold_expression", "")
	_on_success_path = data.get("on_success", "")
	_on_failure_path = data.get("on_failure", "")
	_rewards_on_success = data.get("rewards_on_success", {})
	_rewards_on_failure = data.get("rewards_on_failure", {})
	var stat_key: String = data.get("stat", "")
	if not stat_key in Enums.Stat:
		push_warning("SkillCheckEvent: unknown stat '%s', defaulting to LUCK" % stat_key)
		_stat = Enums.Stat.LUCK
		return
	_stat = Enums.Stat[stat_key]

# --- Enter / Exit ---

func _on_enter(game: Node) -> void:
	skill_check_requested.connect(game._on_skill_check_requested)
	dialogue_requested.connect(game._on_dialogue_requested)


func _on_exit(game: Node) -> void:
	skill_check_requested.disconnect(game._on_skill_check_requested)
	dialogue_requested.disconnect(game._on_dialogue_requested)


# --- Phase Hooks ---

func _on_setup() -> void:
	pass


func _on_running() -> void:
	skill_check_requested.emit(_stat, _label, _threshold_expression)


func _on_resolution() -> void:
	rewards = _rewards_on_success if _success else _rewards_on_failure
	var path: String = _on_success_path if _success else _on_failure_path
	if path == "":
		_set_phase(Phase.COMPLETE)
		return
	var dialogue_data: Dictionary = DialogueLoader.load_dict(path)
	if dialogue_data.is_empty():
		push_warning("SkillCheckEvent: could not load dialogue at '%s'" % path)
		_set_phase(Phase.COMPLETE)
		return
	dialogue_requested.emit(dialogue_data)


# --- Public API ---

# Called by game.gd when the skill check panel resolves.
func on_skill_check_complete(success: bool) -> void:
	_success = success
	_set_phase(Phase.RESOLUTION)


# Called by game.gd when gui.dialogue_complete fires during RESOLUTION.
func on_dialogue_complete() -> void:
	_set_phase(Phase.COMPLETE)
