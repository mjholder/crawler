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
## Fixed / named magic items: baked-in payload seeded onto a fresh ItemInstance (ItemInstance.wrap).
## These are authoring-time defaults, not rolled loot — but seeded tags/riders behave identically to
## rolled ones (compose at read time). Seeding happens for fresh items only; save/load stays
## authoritative, so it never double-applies. See item_instance.gd.
## base_rarity sets the fresh item's scaling tier. A baked rider applies regardless of base_rarity —
## the rider's own `rarity` is only pool metadata (RiderData) — so a designer picks base_rarity for
## the scaling they want, not to "unlock" the baked rider.
@export var base_rarity: Enums.Rarity = Enums.Rarity.COMMON
@export var default_tags: Array[TagData] = []
@export var default_riders: Array[RiderData] = []
## Hand actions this item grants when equipped. In dual-action combat these become the
## action group for the hand holding this item (mainhand = WEAPON slot, offhand = OFFHAND).
@export var attacks: Array[Resource] = []  # Array[AttackData]
## When true this item is a spellcasting focus: its hand can cast the player's prepared
## repertoire (get_castable_spells). No focus in either hand means no casting at all.
@export var grants_casting: bool = false
@export var on_equip_effects: Array[Resource] = []
@export var on_unequip_effects: Array[Resource] = []
@export var proc_effects: Array[Resource] = []       # Array[ProcDef]
@export var conditional_modifiers: Array[Resource] = []  # Array[ConditionalModifier]
@export var spell_cost_multiplier: float = 1.0
@export var bonus_prep_slots: int = 0
@export var bonus_mana_regen: float = 0.0
@export var affinity_tags: Array[StringName] = []
