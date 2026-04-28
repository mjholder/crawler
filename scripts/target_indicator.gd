class_name TargetIndicator
extends Node2D


func _ready() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(self, "modulate:a", 0.4, 0.4)
	tween.tween_property(self, "modulate:a", 1.0, 0.4)


func _draw() -> void:
	draw_arc(Vector2(0, -50), 40.0, 0.0, TAU, 48, Color.YELLOW, 4.0)
