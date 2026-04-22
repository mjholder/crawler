class_name BossEvent
extends CombatEvent

# --- Signals ---

signal boss_defeated


# --- Enter / Exit ---

func _on_enter(game: Node) -> void:
	super._on_enter(game)
	boss_defeated.connect(game._on_boss_defeated, CONNECT_ONE_SHOT)


func _on_exit(game: Node) -> void:
	if boss_defeated.is_connected(game._on_boss_defeated):
		boss_defeated.disconnect(game._on_boss_defeated)
	super._on_exit(game)


# --- Phase Control ---

func _advance_phase() -> void:
	var is_last_wave: bool = _current_wave_index >= _waves.size() - 1
	if is_last_wave:
		# Emit before RESOLUTION so _pre_dialogue_state in game.gd captures VICTORY,
		# not PLAYER_TURN, when the on_victory dialogue opens.
		boss_defeated.emit()
	super._advance_phase()
