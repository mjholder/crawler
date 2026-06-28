class_name EndActEvent
extends Event

# --- Signals ---

## Emitted during RUNNING to open the end-of-act town hub. The event stays in
## RUNNING while the town is open so the player can visit services (temple, …)
## any number of times before travelling onward.
signal town_requested

# --- Config ---

var _game: Node = null
var _cost: int = 0


# --- Public API ---

func initialize(data: Dictionary) -> void:
	_cost = data.get("ascension_cost", 0)


## Gold tithe charged at the temple. Read by game.gd when opening the temple panel.
func ascension_cost() -> int:
	return _cost


## Called by game.gd when the player chooses to leave the town for the next act.
func on_travel_onward() -> void:
	_advance_phase()


# --- Enter / Exit ---

func _on_enter(game: Node) -> void:
	_game = game
	town_requested.connect(game._on_town_requested)


func _on_exit(game: Node) -> void:
	town_requested.disconnect(game._on_town_requested)


# --- Phase Hooks ---

func _on_running() -> void:
	town_requested.emit()


func _on_resolution() -> void:
	rewards = {}
