class_name StatusInstance
extends Resource

@export var data: StatusData = null
@export var turns_remaining: int = 0

# Intensity lever for every status. Re-applying increments this on the existing instance rather
# than adding a second; on_tick strength scales by it, and for stack-decaying statuses it also IS
# the remaining lifetime (a crit doubles it, so a crit stun lasts twice as long).
@export var stacks: int = 1

# Flat per-stack bonus added to this DoT's tick damage, seeded from a PotencyRider at apply time and
# kept here so it survives across ticks (the weapon context is gone by tick time). 0 = plain. On
# re-application the strongest potency seen wins (the deepest venom stays in the wound). Orthogonal to
# stacks: potency raises how hard each tick bites, stacks how long it bites for. See DamageEffect.apply_tick.
@export var potency: int = 0

# Not exported — Node refs can't be serialized. After a save/load, source is null
# and StatExprEval falls back to zeros for source stats. Current tick effects
# (poison "3", regen "5") use flat expressions, so this is safe for all authored statuses.
var source: Node = null

# Not exported — holds this instance's live bus connections when its StatusData carries
# `subscriptions`. Cleared (disconnected) when the instance is removed/expired/swept.
var _subscription: Subscription = null
