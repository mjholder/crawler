class_name InnateSpellRider
extends RiderData

## Grants a castable spell in the hand holding this item, without consuming a prep slot — "a free
## prep slot that arrives pre-filled" (journal/ideas/equipment-tags-and-riders). Registered directly
## into the hand's spell registry by Player._build_hand_actions, so it bypasses the prepared
## repertoire entirely. Worth more than any stat roll for that reason, so it should carry spells the
## player wouldn't voluntarily prepare, or it distorts the repertoire decision.

@export var spell: SpellData = null
