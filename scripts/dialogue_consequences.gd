class_name DialogueConsequences
extends Node

# --- Setup ---

var _game: Game
var flags: Dictionary = {}

func _ready() -> void:
	_game = get_parent() as Game

# --- Dispatch ---

func execute(action: String, value: Variant) -> void:
	if not has_method(action):
		push_warning("DialogueConsequences: unknown action '%s'" % action)
		return
	call(action, value)

# --- Consequence Methods ---

func give_item(value: Variant) -> void:
	var path := String(value)
	if path == "" or not ResourceLoader.exists(path):
		push_warning("[DialogueConsequences] give_item: invalid path '%s'" % path)
		return
	var data := load(path) as EquipmentData
	if data == null:
		push_warning("[DialogueConsequences] give_item: not EquipmentData at '%s'" % path)
		return
	if _game.player._inventory.add_to_bag(data):
		print("[DialogueConsequences] give_item: %s" % data.display_name)
	else:
		push_warning("[DialogueConsequences] give_item: bag full, could not add %s" % data.display_name)

func give_gold(value: Variant) -> void:
	_game.player.add_gold(int(value))
	print("[DialogueConsequences] give_gold: %s" % value)

func set_flag(value: Variant) -> void:
	flags[value] = true
	print("[DialogueConsequences] set_flag: %s" % value)

func trigger_event(value: Variant) -> void:
	print("[DialogueConsequences] trigger_event: %s" % value)
