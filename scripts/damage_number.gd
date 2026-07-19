class_name DamageNumber
extends Control

## A single floating damage/heal number. Instanced by GUI over a target's health bar,
## it pops up in an arch, falls past its spawn point, and fades — then frees itself.
## Motion is a script Tween (per-number randomized arc); the fade is the embedded
## AnimationPlayer track. Multiple numbers coexist, each with independent hue/alpha.

enum Kind { DAMAGE, HEAL, MANA, ARMOR }  # CRIT later, once take_damage carries a crit flag

@onready var _label: Label = $DamageNumberLabel
@onready var _anim: AnimationPlayer = $DamageNumberAnimationPlayer

# Each range is (min, max); every number rolls its own value inside the range so a
# burst of numbers spreads out naturally instead of tracing identical paths.
@export var rise_range: Vector2 = Vector2(40.0, 64.0)    ## peak pop height (px)
@export var fall_range: Vector2 = Vector2(80.0, 112.0)   ## net downward drop by end (px)
@export var drift_range: Vector2 = Vector2(16.0, 40.0)   ## sideways travel (px); positive = left→right, negative = right→left
@export var duration_range: Vector2 = Vector2(0.7, 0.9)  ## keep centered on the fade length (0.8s)

var _start: Vector2
var _rise: float
var _fall: float
var _drift: float
var _pending: Dictionary = {}  # set before add_child, applied in _ready


## Set the number's value and kind. Safe to call before the node enters the tree
## (the spawner calls this between instantiate()/add_child()); applied in _ready.
func setup(amount: float, kind: int = Kind.DAMAGE) -> void:
	_pending = {"amount": amount, "kind": kind}
	if is_node_ready():
		_apply()


func _ready() -> void:
	_anim.animation_finished.connect(func(_n: StringName) -> void: queue_free())
	if not _pending.is_empty():
		_apply()


func _apply() -> void:
	var amount: float = _pending["amount"]
	var kind: int = _pending["kind"]
	match kind:
		Kind.HEAL:
			_label.text = "+%d" % roundi(amount)
			_label.label_settings.font_color = Color(0.45, 0.9, 0.45)  # green
		Kind.MANA:
			_label.text = "-%d" % roundi(amount)
			_label.label_settings.font_color = Color(0.4, 0.6, 1.0)  # blue
		Kind.ARMOR:
			_label.text = "-%d" % roundi(amount)
			_label.label_settings.font_color = Color(0.75, 0.78, 0.85)  # steel/gray
		_:
			_label.text = "-%d" % roundi(amount)
			_label.label_settings.font_color = Color(1, 1, 1)  # white/neutral
	_start = position
	_rise = randf_range(rise_range.x, rise_range.y)
	_fall = randf_range(fall_range.x, fall_range.y)
	_drift = randf_range(drift_range.x, drift_range.y)
	_anim.play("fade")
	create_tween().tween_method(_arc, 0.0, 1.0, randf_range(duration_range.x, duration_range.y))


## Closed-form arch: a symmetric hump (up then back) plus a net downward drag, so the
## number pops up, curves, and ends below the spawn point. p in [0, 1].
func _arc(p: float) -> void:
	var x := _start.x + _drift * p
	var y := _start.y - _rise * 4.0 * p * (1.0 - p) + _fall * p
	position = Vector2(x, y)
