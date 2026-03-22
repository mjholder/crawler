class_name Enums

# --- Turn Flow ---

enum TurnState { NO_TURN, PLAYER_TURN, ENEMY_TURN, GAME_OVER, ENEMY_CLEARED }

# --- Equipment ---

enum Stat {
	STRENGTH,    # 0
	DEFENSE,     # 1
	CONSTITUTION, # 2
	AGILITY,     # 3
	SPIRIT,      # 4
	LUCK         # 5
	# When setting stat_modifiers in a .tres file, use the integer key.
	# e.g. { 0: 10.0 } adds +10 STRENGTH
}

enum Slot { WEAPON, ARMOR }
