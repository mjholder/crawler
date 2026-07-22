class_name PlayerClassData
extends Resource

@export var class_name_text: String = ""
@export var description: String = ""

# --- Starting Stats ---
## Defense is NOT a class attribute — it's equipment-derived (see character.md).
@export var strength: float = 50.0
@export var constitution: float = 50.0
@export var agility: float = 50.0
@export var spirit: float = 50.0
@export var luck: float = 50.0

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

# --- Spells ---
## Number of prepared spell slots this class starts with.
@export var starting_prep_slots: int = 2

## Full spell roster the player knows at run start.
@export var starting_learned_spells: Array[Resource] = []  # Array[SpellData]

## Subset of learned spells that are prepared (active) at run start.
@export var starting_prepared_spells: Array[Resource] = []  # Array[SpellData]

## Tomes placed in the inventory at run start (for testing / class kits).
@export var starting_tomes: Array[Resource] = []  # Array[TomeData]

# --- Mana Regen ---
## Mana restored at the start of each player turn.
@export var mana_regen_per_turn: float = 0.0

## Mana restored each time an enemy is killed.
@export var mana_on_kill: float = 0.0
