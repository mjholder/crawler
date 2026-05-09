class_name Weapon
extends Equipment

signal animation_finished
signal cast_animation_finished
signal hit_landed

# --- State ---

var _is_casting: bool = false

# --- Node References ---

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var _attack_player: AudioStreamPlayer2D = $SFX/AttackPlayer


func _ready() -> void:
	super._ready()
	if data is WeaponData:
		_attack_player.stream = (data as WeaponData).attack_sfx
	anim_player.animation_finished.connect(_on_anim_player_finished)


func _on_player_attacked(_attack_data: AttackData, _targets: Array) -> void:
	if _attack_player.stream != null:
		_attack_player.play()
	print("[WEAPON] Player attacked with %s" % data.item_name)
	anim_player.play(&"attack")


func _on_player_cast(_spell: SpellData, _targets: Array) -> void:
	_is_casting = true
	if _attack_player.stream != null:
		_attack_player.play()
	print("[WEAPON] Player casts with %s" % data.item_name)
	var anim := &"cast" if anim_player.has_animation(&"cast") else &"attack"
	anim_player.play(anim)


func _emit_hit_landed() -> void:
	hit_landed.emit()


func _on_anim_player_finished(anim_name: StringName) -> void:
	print("[WEAPON] Animation finished: %s" % anim_name)
	if anim_name == &"cast":
		_is_casting = false
		cast_animation_finished.emit()
		anim_player.play(&"idle")
	elif anim_name == &"attack":
		if _is_casting:
			_is_casting = false
			cast_animation_finished.emit()
		else:
			animation_finished.emit()
			print("[WEAPON] Attack animation finished")
		anim_player.play(&"idle")
