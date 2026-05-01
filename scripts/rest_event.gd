class_name RestEvent
extends Event

# --- Signals ---

signal rest_requested

# --- Config ---

var heal_expression: String = "max_health"

var _eval := StatExprEval.new()


# --- Public API ---

func initialize(data: Dictionary) -> void:
	heal_expression = data.get("heal_expression", "max_health")


func get_heal_amount(target: Node) -> float:
	return _eval.evaluate(heal_expression, target)


func on_rest_complete() -> void:
	_advance_phase()


# --- Enter / Exit ---

func _on_enter(game: Node) -> void:
	rest_requested.connect(game._on_rest_requested)


func _on_exit(game: Node) -> void:
	rest_requested.disconnect(game._on_rest_requested)


# --- Phase Hooks ---

func _on_running() -> void:
	rest_requested.emit()
