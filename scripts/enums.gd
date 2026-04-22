class_name Enums

# --- Game State ---

enum GameState { MAIN_MENU, CHARACTER_CREATION, WORLD_MAP, DUNGEON, GAME_OVER, VICTORY }

# --- Turn Flow ---

enum TurnState { NO_TURN, PLAYER_TURN, ENEMY_TURN, GAME_OVER, ENEMY_CLEARED, DIALOGUE, VICTORY }

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

enum Slot { WEAPON, HANDS, FEET, LEGS, TORSO, HEAD }

# --- World Map ---

enum NodeType { DUNGEON, SHOP, REST, BOSS }
enum NodeState { LOCKED, AVAILABLE, COMPLETED }
