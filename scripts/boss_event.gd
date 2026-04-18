class_name BossEvent
extends CombatEvent

# --- Signals ---

signal boss_defeated


# --- Phase Control ---

func _advance_phase() -> void:
	var is_last_wave: bool = _current_wave_index >= _waves.size() - 1
	if is_last_wave:
		# Emit before RESOLUTION so _pre_dialogue_state in game.gd captures VICTORY,
		# not PLAYER_TURN, when the on_victory dialogue opens.
		boss_defeated.emit()
	super._advance_phase()
