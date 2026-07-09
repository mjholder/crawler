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
@export var persistence: Persistence = Persistence.COMBAT

# Shatter: while any active status has this set, the bearer's refresh_armor() is skipped,
# so the per-round armor buffer is not refilled (checked in Player/Enemy.refresh_armor).
@export var suppresses_armor_refresh: bool = false

# Signal-name (StringName) -> Effect. Wired to the game.gd lifecycle bus when the status is
# applied and disconnected when it is removed/cleared (mirrors BlessingData.subscriptions).
# Handlers fire effect.apply(source, bearer). Use for reactive statuses (e.g. retaliate
# on player_damaged); per-turn ticks belong on on_tick, not here.
@export var subscriptions: Dictionary = {}
