class_name BossEvent
extends CombatEvent

# --- Signals ---

signal boss_defeated


# --- Phase Control ---

func _advance_phase() -> void:
	match phase:
		Phase.RUNNING:
			_set_phase(Phase.RESOLUTION)
			boss_defeated.emit()
