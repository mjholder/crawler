class_name RestEvent
extends Event

# --- Signals ---

signal rest_requested

# --- Config ---

var _heal_percent: float = 1.0


# --- Public API ---

func initialize(data: Dictionary) -> void:
	_heal_percent = data.get("heal_percent", 1.0)


func get_heal_amount(max_health: float) -> float:
	return max_health * _heal_percent


func on_rest_complete() -> void:
	_advance_phase()


# --- Phase Hooks ---

func _on_running() -> void:
	rest_requested.emit()
