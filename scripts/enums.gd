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
