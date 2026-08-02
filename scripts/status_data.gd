class_name StatusData
extends Resource

enum Persistence { COMBAT, PERSISTENT }

@export var tag: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D = null
@export var duration: int = 3
@export var stat_modifiers: Dictionary = {}
# Attack-coefficient buff — the `coeff` in `power * coeff + scale * scaling`. While active, the
# bearer's attacks resolve coeff as (base_K + Σ coefficient_add) * Π coefficient_mult. 0.0 and 1.0
# are the no-op identities. See Combatant.get_attack_coeff_add / _mult and AttackCoeffBuffEffect.
@export var coefficient_add: float = 0.0
@export var coefficient_mult: float = 1.0
@export var prevents_action: bool = false
@export var on_apply: Resource = null
@export var on_tick: Resource = null
@export var on_expire: Resource = null

# Every status is stack-based: re-applying bumps a single instance's `stacks` (the one intensity
# lever), and a crit doubles the granted stacks. What stacks *mean* is set by the two flags below.
#
# stack_decays — classic-poison cool-down: each tick consumes one stack and the status expires
# when stacks reach 0, so its LIFETIME is the stack count (3 stacks -> 3 turns). DoTs ramp their
# damage DOWN as the pool drains (3/2/1); control/buff statuses (stun, haste) just live one turn
# per stack, so a crit that doubles stacks doubles their duration. When false, lifetime is driven
# by `duration` and stacks only scale per-tick effect strength (bleed = sustained per-stack damage).
@export var stack_decays: bool = false

# Burst (Fire's signature): when true, the whole stack pool discharges as a single-turn
# countdown at the START of the bearer's turn (via Combatant.resolve_turn_start_bursts) —
# on_tick fires once per stack for stacks, stacks-1, ... 1, then the status is removed. This
# replaces the per-turn _tick_statuses cadence: a burst is a one-round burst, not a lingering
# DoT. Contrast stack_decays (poison), which drains ONE stack per turn across many turns.
@export var burst_on_turn_start: bool = false

@export var persistence: Persistence = Persistence.COMBAT

# Shatter: while any active status has this set, the bearer's refresh_armor() is skipped,
# so the per-round armor buffer is not refilled (checked in Player/Enemy.refresh_armor).
@export var suppresses_armor_refresh: bool = false

# Vulnerable/ward: multiplies incoming ATTACK damage while active (DoT ticks are unaffected —
# they pass is_attack=false to take_damage). 1.0 = no change, 1.5 = +50% taken, 0.5 = warded.
@export var incoming_attack_multiplier: float = 1.0

# Signal-name (StringName) -> Effect. Wired to the game.gd lifecycle bus when the status is
# applied and disconnected when it is removed/cleared (mirrors BlessingData.subscriptions).
# Handlers fire effect.apply(source, bearer). Use for reactive statuses (e.g. retaliate
# on player_damaged); per-turn ticks belong on on_tick, not here.
@export var subscriptions: Dictionary = {}
