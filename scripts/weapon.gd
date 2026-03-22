class_name Weapon
extends Equipment

signal animation_finished

# --- Node References ---

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var _attack_player: AudioStreamPlayer2D = $SFX/AttackPlayer


func _ready() -> void:
	super._ready()
	if data is WeaponData:
		_attack_player.stream = (data as WeaponData).attack_sfx
	_sprite.animation_finished.connect(_on_sprite_animation_finished)


func _on_player_attacked(damage: float) -> void:
	if _attack_player.stream != null:
		_attack_player.play()
	print("[WEAPON] Player attacked with %s" % data.item_name)
	_sprite.play("attack")


func _on_sprite_animation_finished() -> void:
	print("[WEAPON] Animation finished: %s" % _sprite.animation)
	if _sprite.animation == &"attack":
		animation_finished.emit()
		print("[WEAPON] Attack animation finished")
		_sprite.play("idle")
