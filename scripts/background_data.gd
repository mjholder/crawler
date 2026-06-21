class_name BackgroundData
extends Resource

## "Who you were" — a character-creation layer alongside class and patron saint.
## Civilians forced to adventure: a small stat shift, starting gold, and one
## static passive tied to the character's former life. Fixed across the run.

@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null

## Flat stat shift applied for the whole run. Enums.Stat (int) -> float.
## Values may be negative to give the gothic-tone drawback that rhymes with saint tithes.
@export var stat_modifiers: Dictionary = {}

## Gold the character starts the run with.
@export var starting_gold: int = 0

## Multiplier applied to gold rewarded by events. Read by game.gd._apply_rewards.
@export var gold_reward_multiplier: float = 1.0

## Stacks onto ShopData.buy_price_multiplier (lower = cheaper buys).
@export var shop_buy_multiplier: float = 1.0

## Stacks onto ShopData.sell_price_multiplier (higher = better sells).
@export var shop_sell_multiplier: float = 1.0

## The one unique passive. Granted via Player.add_blessing at run start, so it
## gets the full BlessingData treatment (stat_modifiers + lifecycle subscriptions).
@export var passive: BlessingData = null
