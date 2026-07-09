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
