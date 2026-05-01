class_name Equipment
extends Node2D

# --- Data ---

@export var data: EquipmentData

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


func _on_unequipped() -> void:
	pass


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
