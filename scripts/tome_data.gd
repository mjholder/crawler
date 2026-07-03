class_name TomeData
extends EquipmentData

## A tome is a bag item that teaches a spell when used (clicked). It lives in the bag
## like any other item; the inventory panel routes a tome click to Player.learn_spell
## instead of equipping. Non-tome equipment fields inherited from EquipmentData are
## unused and keep their defaults.
@export var spell: SpellData = null
