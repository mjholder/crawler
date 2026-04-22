class_name ConsumableData
extends EquipmentData

enum Effect { HEAL_FLAT, HEAL_PERCENT, DAMAGE_ALL, STAT_BUFF }

@export var effect: Effect = Effect.HEAL_FLAT
@export var effect_value: float = 0.0
@export var buff_stat: Enums.Stat = Enums.Stat.STRENGTH
@export var buff_duration: int = 3
@export var use_sfx: AudioStream
var is_consumable: bool = true
