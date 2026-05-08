class_name EquipmentData
extends Resource

@export var item_name: String = ""
@export var description: String = ""
@export var sprite_frames: SpriteFrames
@export var paper_doll_front: Texture2D
@export var paper_doll_back: Texture2D
@export var equip_sfx: AudioStream
@export var unequip_sfx: AudioStream
@export var stat_modifiers: Dictionary  # Enums.Stat → float
@export var scene: PackedScene  # Equipment or Weapon scene to instantiate
@export var slot: Enums.Slot = Enums.Slot.WEAPON
@export var is_ring: bool = false
@export var price: int = 0
@export var on_equip_effects: Array[Resource] = []
@export var on_unequip_effects: Array[Resource] = []
@export var proc_effects: Array[Resource] = []       # Array[ProcDef]
@export var conditional_modifiers: Array[Resource] = []  # Array[ConditionalModifier]
@export var spell_cost_multiplier: float = 1.0
@export var bonus_prep_slots: int = 0
