class_name Enums

# --- Game State ---

enum GameState {
	MAIN_MENU,        # 0
	CHARACTER_CREATION, # 1
	WORLD_MAP,        # 2
	DUNGEON,          # 3
	GAME_OVER,        # 4
	VICTORY           # 5
}

# --- Turn Flow ---

enum TurnState {
	NO_TURN,       # 0
	PLAYER_TURN,   # 1
	ENEMY_TURN,    # 2
	GAME_OVER,     # 3
	ENEMY_CLEARED, # 4
	DIALOGUE,      # 5
	VICTORY        # 6
}

# --- Equipment ---

enum Stat {
	STRENGTH,     # 0
	DEFENSE,      # 1
	CONSTITUTION, # 2
	AGILITY,      # 3
	SPIRIT,       # 4
	LUCK          # 5
	# When setting stat_modifiers in a .tres file, use the integer key.
	# e.g. { 0: 10.0 } adds +10 STRENGTH
}

enum Slot {
	WEAPON,  # 0
	HANDS,   # 1
	FEET,    # 2
	LEGS,    # 3
	TORSO,   # 4
	HEAD,    # 5
	OFFHAND  # 6
	# When setting slot in a .tres file, use the integer key.
	# e.g. slot = 5 is HEAD, slot = 6 is OFFHAND
}

# Which hand(s) a weapon may be equipped into. Drives the equip UI's slot routing:
# MAINHAND_ONLY / OFFHAND_ONLY force a slot; EITHER prompts the player to choose.
enum HandRestriction {
	MAINHAND_ONLY,  # 0
	OFFHAND_ONLY,   # 1
	EITHER          # 2
}

# --- World Map ---

enum NodeType {
	DUNGEON, # 0
	SHOP,    # 1
	REST,    # 2
	BOSS     # 3
}

enum NodeState {
	LOCKED,    # 0
	AVAILABLE, # 1
	COMPLETED  # 2
}

# --- Dungeon Events ---

enum EventType {
	COMBAT,      # 0
	BOSS,        # 1
	DIALOGUE,    # 2
	SKILL_CHECK, # 3
	REST         # 4
	# When setting event_type in a .tres file, use the integer key
	# (matches the old @export_enum order).
}

# Bitmask — values are powers of two; combine with bitwise OR.
# Keep in sync with the @export_flags(...) labels on tags / floor_tags.
enum FloorTag {
	SHORT  = 1,
	MEDIUM = 2,
	MIXED  = 4,
	DEMO   = 8
}
