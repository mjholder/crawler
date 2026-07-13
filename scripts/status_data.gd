class_name StatusData
extends Resource

enum StackPolicy { REFRESH, STACK, MAX_DURATION }
enum Persistence { COMBAT, PERSISTENT }

@export var tag: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D = null
@export var duration: int = 3
@export var stat_modifiers: Dictionary = {}
@export var prevents_action: bool = false
@export var on_apply: Resource = null
@export var on_tick: Resource = null
@export var on_expire: Resource = null
@export var stack_policy: StackPolicy = StackPolicy.REFRESH

# Classic-poison decay: when true, each tick consumes one stack and the status expires when
# stacks reach 0, so damage ramps DOWN as the pool drains (e.g. 3 stacks -> 3/2/1). Lifetime
# is driven by the stack count, not `duration`. When false, lifetime is driven by `duration`
# and stacks only scale per-tick damage (bleed = sustained, burn = duration-decay).
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

# Signal-name (StringName) -> Effect. Wired to the game.gd lifecycle bus when the status is
# applied and disconnected when it is removed/cleared (mirrors BlessingData.subscriptions).
# Handlers fire effect.apply(source, bearer). Use for reactive statuses (e.g. retaliate
# on player_damaged); per-turn ticks belong on on_tick, not here.
@export var subscriptions: Dictionary = {}
