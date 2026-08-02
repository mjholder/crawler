class_name Equipment
extends Node2D

# --- Data ---

@export var data: EquipmentData
## The runtime instance backing this node, set at equip time. When present, procs are drawn from
## its composed (base + tags) list so tag-added procs subscribe; null falls back to base data.
var item_instance: ItemInstance = null

# --- Passive State ---

var _game: Game = null
var _subscription: Subscription = null
var _eval: StatExprEval = StatExprEval.new()

# --- Node References ---

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _anim_player: AnimationPlayer = $AnimationPlayer
@onready var _equip_player: AudioStreamPlayer2D = $SFX/EquipPlayer
@onready var _unequip_player: AudioStreamPlayer2D = $SFX/UnequipPlayer


func _ready() -> void:
	if data:
		_sprite.sprite_frames = data.sprite_frames
		_equip_player.stream = data.equip_sfx
		_unequip_player.stream = data.unequip_sfx
	_anim_player.play(&"idle")


func get_modifier(stat: Enums.Stat) -> float:
	if data == null or not data.stat_modifiers.has(stat):
		return 0.0
	return data.stat_modifiers[stat]


func play_equip() -> void:
	if _equip_player.stream != null:
		_equip_player.play()


func play_unequip() -> void:
	if _unequip_player.stream != null:
		_unequip_player.play()


# --- Extension Hooks ---

func _on_equipped() -> void:
	_scale_sprite_to_viewport()
	# Effective procs = base + tags (via the instance); fall back to base data when unwrapped.
	var procs: Array = item_instance.effective_proc_effects() if item_instance != null else (data.proc_effects if data != null else [])
	if data == null or _game == null or procs.is_empty():
		return
	var owner_node := get_parent()
	_subscription = Subscription.new()
	for proc_res in procs:
		var proc := proc_res as ProcDef
		if proc == null or proc.effect == null or proc.trigger == &"":
			continue
		var sig := Signal(_game, proc.trigger)
		_subscription.add(sig, _make_proc_handler(proc, owner_node))


func _on_unequipped() -> void:
	if _subscription != null:
		_subscription.clear_all()
		_subscription = null


# --- Proc Helpers ---

func _make_proc_handler(proc: ProcDef, owner: Node) -> Callable:
	var effect := proc.effect as Effect
	var chance_expr := proc.chance_expression
	match proc.trigger:
		&"player_attack_hit":
			var to_owner := proc.apply_to_owner
			return func(_atk: AttackData, targets: Array) -> void:
				if not _roll_chance(chance_expr, owner):
					return
				if to_owner:
					effect.apply(owner, owner)
				else:
					for t in targets:
						effect.apply(owner, t)
		&"player_damaged", &"player_healed":
			return func(_amount: float) -> void:
				if not _roll_chance(chance_expr, owner):
					return
				effect.apply(owner, owner)
		&"enemy_attack_hit":
			return func(enemy: Enemy, _dmg: float) -> void:
				if not _roll_chance(chance_expr, owner):
					return
				effect.apply(owner, enemy)
		&"enemy_died":
			return func(_enemy: Enemy) -> void:
				if not _roll_chance(chance_expr, owner):
					return
				effect.apply(owner, owner)
		_:
			# Signals with no relevant payload: fire effect on owner.
			# Godot drops extra signal args silently, so this works for any signal.
			return func() -> void:
				if not _roll_chance(chance_expr, owner):
					return
				effect.apply(owner, owner)


func _roll_chance(chance_expr: String, owner: Node) -> bool:
	return randf() < _eval.evaluate(chance_expr, owner)


# --- Helpers ---

func _scale_sprite_to_viewport() -> void:
	if _sprite.sprite_frames == null:
		return
	var screen_size := get_viewport_rect().size
	var texture := _sprite.sprite_frames.get_frame_texture("idle", 0)
	if texture == null:
		return
	var sprite_size := texture.get_size()
	var scale_factor := minf(screen_size.x / sprite_size.x, screen_size.y / sprite_size.y)
	_sprite.scale = Vector2(scale_factor, scale_factor)
