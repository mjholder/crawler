class_name CombatMessage
extends Control

## A single floating combat-log line. Instanced by CombatLog, it plays the
## float-up-and-fade animation once and then frees itself. Multiple instances can
## coexist (staggered spawns) to form a rising stream during multi-event turns.

@onready var _label: Label = $CombatLogLabel
@onready var _anim: AnimationPlayer = $AnimationPlayer

var _pending_text: String = ""


## Set the message text. Safe to call before the node enters the tree (the spawner
## calls this between instantiate() and add_child()); the text is applied in _ready.
func setup(text: String) -> void:
	_pending_text = text
	if is_node_ready():
		_label.text = text


func _ready() -> void:
	_label.text = _pending_text
	_anim.animation_finished.connect(_on_animation_finished)
	_anim.play("CombatMessageFloat")


func _on_animation_finished(_anim_name: StringName) -> void:
	queue_free()


## Time (seconds into the float) of a named marker on CombatMessageFloat, or -1 if
## the animation has no such marker. Lets the spawner pace off the animation timeline
## instead of a fixed gap — add a marker in the AnimationPlayer editor to use it.
func advance_time(marker: StringName) -> float:
	var anim := _anim.get_animation(&"CombatMessageFloat")
	if anim == null:
		return -1.0
	return anim.get_marker_time(marker)
