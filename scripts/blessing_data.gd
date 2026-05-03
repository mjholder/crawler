class_name BlessingData
extends Resource

@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null

# Flat stat bonuses active for the whole run while this blessing is held.
@export var stat_modifiers: Dictionary = {}

# Signal-name (StringName) -> Effect. Player wires these to the game lifecycle
# bus on add_blessing and disconnects them on remove_blessing.
# Effects are applied as effect.apply(player, player) — blessings always target
# the owner, never enemies. Use equipment proc_effects for hostile-target procs.
@export var subscriptions: Dictionary = {}
