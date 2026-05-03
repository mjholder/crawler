class_name PlayerClassData
extends Resource

@export var class_name_text: String = ""
@export var description: String = ""

# --- Starting Stats ---
@export var strength: float = 50.0
@export var defense: float = 50.0
@export var constitution: float = 50.0
@export var agility: float = 50.0
@export var spirit: float = 50.0
@export var luck: float = 50.0

# --- Health ---
## Flat bonus added on top of CON-derived base max health.
## max_health = (effective_CON * health_modifier) + class_health_bonus
@export var class_health_bonus: float = 0.0

# --- Per-Level Growth ---
## Stat bonuses automatically applied each level-up. Enums.Stat (int) -> float.
## e.g. { 0: 3.0, 2: 2.0 } means +3 STR and +2 CON per level.
@export var growth_rates: Dictionary = {}

# --- Starting Equipment ---
## Equipment to auto-equip on game start. Enums.Slot (int) -> EquipmentData.
@export var starting_equipped: Dictionary = {}

## Rings to auto-equip on game start.
@export var starting_rings: Array[EquipmentData] = []

## Items placed in the bag on game start.
@export var starting_bag: Array[EquipmentData] = []

## Number of consumable belt slots this class starts with.
@export var starting_consumable_slots: int = 2

## Consumables auto-equipped to belt slots on game start.
@export var starting_consumables: Array[ConsumableData] = []

## Blessings granted immediately at run start.
@export var starting_blessings: Array[BlessingData] = []
