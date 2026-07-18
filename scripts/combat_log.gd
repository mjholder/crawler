class_name CombatLog
extends Control

## Combat message feed. Each call to push() spawns a self-freeing CombatMessage that
## floats up and fades. Consecutive messages are staggered by spawn_gap so an earlier
## one drifts clear before the next appears — a burst reads as a rising stream rather
## than an unreadable pile. Damage numbers are handled separately.

const MESSAGE_SCENE := preload("res://scenes/combat_message.tscn")

## Fallback seconds between consecutive spawns, used only when the message animation
## has no `advance_marker`. Author the marker in the AnimationPlayer to pace off the
## timeline instead (spacing then tracks the animation automatically).
@export var spawn_gap: float = 0.2
## If CombatMessageFloat defines a marker with this name, the next message spawns when
## the current one reaches it (rather than after spawn_gap). Empty/absent → spawn_gap.
@export var advance_marker: StringName = &"advance"
## Hard cap on the backlog; oldest queued lines are dropped past this so a runaway
## turn can't stall the feed indefinitely.
@export var max_queued: int = 12

var _queue: Array[String] = []
var _draining: bool = false


func push(text: String) -> void:
	_queue.append(text)
	if _queue.size() > max_queued:
		_queue.pop_front()
	if not _draining:
		_drain()


## Drop any queued lines and remove messages still floating. Called on combat
## start/end so lines from one fight don't bleed into the next.
func clear() -> void:
	_queue.clear()
	for child in get_children():
		if child is CombatMessage:
			child.queue_free()


func _drain() -> void:
	_draining = true
	while not _queue.is_empty():
		var message := _spawn(_queue.pop_front())
		await get_tree().create_timer(_gap_for(message)).timeout
	_draining = false


func _spawn(text: String) -> CombatMessage:
	var message: CombatMessage = MESSAGE_SCENE.instantiate()
	message.setup(text)
	add_child(message)
	return message


func _gap_for(message: CombatMessage) -> float:
	var marked := message.advance_time(advance_marker)
	return marked if marked >= 0.0 else spawn_gap
