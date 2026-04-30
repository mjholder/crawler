class_name ConsumableData
extends EquipmentData

enum TargetMode { SELF, ALL_ENEMIES }

@export var target_mode: TargetMode = TargetMode.SELF
@export var effects: Array[Resource] = []
@export var use_sfx: AudioStream
var is_consumable: bool = true
