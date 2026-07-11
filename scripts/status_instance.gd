class_name StatusInstance
extends Resource

@export var data: StatusData = null
@export var turns_remaining: int = 0

# Intensity for STACK-policy statuses (poison, bleed, burn). Re-applying increments this on
# the existing instance rather than adding a second instance; on_tick damage scales by it.
# Always 1 for REFRESH / MAX_DURATION statuses.
@export var stacks: int = 1

# Not exported — Node refs can't be serialized. After a save/load, source is null
# and StatExprEval falls back to zeros for source stats. Current tick effects
# (poison "3", regen "5") use flat expressions, so this is safe for all authored statuses.
var source: Node = null

# Not exported — holds this instance's live bus connections when its StatusData carries
# `subscriptions`. Cleared (disconnected) when the instance is removed/expired/swept.
var _subscription: Subscription = null
