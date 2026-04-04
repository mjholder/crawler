class_name EquipmentData
extends Resource

@export var item_name: String = ""
@export var description: String = ""
@export var sprite_frames: SpriteFrames
@export var equip_sfx: AudioStream
@export var unequip_sfx: AudioStream
@export var stat_modifiers: Dictionary  # Enums.Stat → float
@export var scene: PackedScene  # Equipment or Weapon scene to instantiate
