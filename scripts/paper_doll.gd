class_name PaperDoll
extends Control

const _BASE_TEXTURE := preload("res://assets/sprites/paper_doll/man.png")

@onready var _layers: Dictionary = {
	Enums.Slot.HEAD:  {"front": $HeadLayer},
	Enums.Slot.TORSO: {"front": $TorsoLayer},
	Enums.Slot.LEGS:  {"front": $LegsLayer},
	Enums.Slot.FEET:  {"front": $FeetLayer},
	Enums.Slot.HANDS:  {"front": $HandsFrontLayer, "back": $HandsBackLayer},
	Enums.Slot.WEAPON: {"front": $WeaponLayer},
	Enums.Slot.OFFHAND: {"front": $OffhandLayer},  # mirrored via TextureRect.flip_h
}

var _inventory: Inventory


func _ready() -> void:
	($BaseLayer as TextureRect).texture = _BASE_TEXTURE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(inventory: Inventory) -> void:
	_inventory = inventory
	_inventory.slot_changed.connect(_on_slot_changed)
	for slot in _layers.keys():
		_refresh_slot(slot)


func _on_slot_changed(slot: Enums.Slot, _new: EquipmentData, _old: EquipmentData) -> void:
	_refresh_slot(slot)


func _refresh_slot(slot: Enums.Slot) -> void:
	if not _layers.has(slot):
		return
	var data: EquipmentData = _inventory.get_equipped(slot)
	var entry: Dictionary = _layers[slot]
	(entry["front"] as TextureRect).texture = data.paper_doll_front if data else null
	if entry.has("back"):
		(entry["back"] as TextureRect).texture = data.paper_doll_back if data else null
