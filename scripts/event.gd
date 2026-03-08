class_name Event
extends Node2D

# --- Signals ---

signal event_complete

# --- Phase State ---

enum Phase { SETUP, RUNNING, RESOLUTION, COMPLETE }

var phase: Phase = Phase.SETUP

# --- Public API ---

func start() -> void:
	_set_phase(Phase.SETUP)
	_set_phase(Phase.RUNNING)


# --- Phase Control ---

func _advance_phase() -> void:
	match phase:
		Phase.RUNNING:
			_set_phase(Phase.RESOLUTION)
			_set_phase(Phase.COMPLETE)


func _set_phase(next_phase: Phase) -> void:
	phase = next_phase
	print("[EVENT] Phase: %s" % Phase.keys()[next_phase])
	match phase:
		Phase.SETUP:      _on_setup()
		Phase.RUNNING:    _on_running()
		Phase.RESOLUTION: _on_resolution()
		Phase.COMPLETE:   event_complete.emit()


# --- Extension Hooks ---

func _on_setup() -> void:
	pass


func _on_running() -> void:
	pass


func _on_resolution() -> void:
	pass
