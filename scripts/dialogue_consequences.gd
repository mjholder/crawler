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
	push_warning("[DialogueConsequences] give_item: inventory not implemented — item: %s" % value)

func give_gold(value: Variant) -> void:
	_game.player.add_gold(int(value))
	print("[DialogueConsequences] give_gold: %s" % value)

func set_flag(value: Variant) -> void:
	flags[value] = true
	print("[DialogueConsequences] set_flag: %s" % value)

func trigger_event(value: Variant) -> void:
	print("[DialogueConsequences] trigger_event: %s" % value)
