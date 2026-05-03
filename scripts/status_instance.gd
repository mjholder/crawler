class_name StatusInstance
extends Resource

@export var data: StatusData = null
@export var turns_remaining: int = 0

# Not exported — Node refs can't be serialized. After a save/load, source is null
# and StatExprEval falls back to zeros for source stats. Current tick effects
# (poison "3", regen "5") use flat expressions, so this is safe for all authored statuses.
var source: Node = null
