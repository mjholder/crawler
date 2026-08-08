class_name ItemInstance
extends RefCounted

## Runtime wrapper around an EquipmentData base. The base `.tres` is authored and shared; the
## instance carries the per-item runtime state that must NOT live on disk per item: smithing
## `upgrade_level`, `rarity`, and rolled `tags`. Effective numbers are composed at read time so
## saves stay small and base rebalances still reach items already in a save.
##
## THE LAW (journal/ideas/weapon-anatomy-power-and-scaling.md): smithing (`upgrade_level`) only
## ever moves `power`; rarity only ever moves `scaling`. Smithing's power move is applied per-attack
## (scaled by AttackData.upgrade_scale) rather than folded into flat effective_power, so a multi-hit
## attack can carry a smaller scale. Tags may move both, via power_delta /
## scaling_delta, and are the only path that adds new stat_modifiers / procs / conditionals on
## top of the base. Enforced here — the one place effective numbers are composed.

# --- Tuning tables (the two axes the law separates) ---
## Scaling-coefficient bonus per rarity tier. Rarity is the scaling-only mutation path.
const RARITY_SCALING := {
	Enums.Rarity.COMMON: 0.0,
	Enums.Rarity.UNCOMMON: 0.1,
	Enums.Rarity.RARE: 0.2,
	Enums.Rarity.EPIC: 0.3,
}

var base: EquipmentData = null
var upgrade_level: int = 0
var rarity: Enums.Rarity = Enums.Rarity.COMMON
var tags: Array = []  # Array[TagData]
## Binary, rarity-gated behaviors (RiderData). Composed at read time like tags, but each rider only
## applies when the instance's rarity meets its min_rarity — the gate lives in effective_riders().
var riders: Array = []  # Array[RiderData]


func _init(base_data: EquipmentData = null) -> void:
	base = base_data


## Convenience factory for a FRESH item. Seeds any baked defaults the base declares (base_rarity,
## default_tags, default_riders) — the fixed / named magic-item path. Seeding lives here, not in
## _init, so from_dict() (which rebuilds from a save via ItemInstance.new) stays authoritative and
## never double-applies. Duplicates the arrays so instance mutation can't write back onto the base.
static func wrap(base_data: EquipmentData) -> ItemInstance:
	var inst := ItemInstance.new(base_data)
	if base_data != null:
		inst.rarity = base_data.base_rarity
		inst.tags = base_data.default_tags.duplicate()
		inst.riders = base_data.default_riders.duplicate()
	return inst


# --- Weapon anatomy (composed) ---

func base_power() -> float:
	return (base as WeaponData).power if base is WeaponData else 0.0


func base_scaling() -> float:
	return (base as WeaponData).scaling if base is WeaponData else 0.0


func scaling_stat() -> Enums.Stat:
	return (base as WeaponData).scaling_stat if base is WeaponData else Enums.Stat.STRENGTH


## The attack-independent power: base + Σ tag.power_delta. Smithing does NOT fold in here — its
## bonus is scaled per-attack (AttackData.upgrade_scale) and added at the hit, via smith_power_bonus().
func effective_power() -> float:
	var total := base_power()
	for tag in tags:
		total += tag.power_delta
	return total


## Smithing's power contribution for one attack: upgrade_level × that attack's upgrade_scale. The
## power-only mutation path (THE LAW), now applied per-attack — the caller folds this into the `power`
## var for the specific attack being resolved (see Player.weapon_context_for).
func smith_power_bonus(per_attack_scale: float) -> float:
	return float(upgrade_level) * per_attack_scale


## scaling = base + rarity (scaling-only) + Σ tag.scaling_delta.
func effective_scaling() -> float:
	var total := base_scaling() + float(RARITY_SCALING.get(rarity, 0.0))
	for tag in tags:
		total += tag.scaling_delta
	return total


# --- Passive modifiers (base + tags) ---

## Base stat_modifiers with every tag's stat_modifiers summed on top.
func effective_stat_modifiers() -> Dictionary:
	var out: Dictionary = base.stat_modifiers.duplicate() if base != null else {}
	for tag in tags:
		for stat in tag.stat_modifiers:
			out[stat] = out.get(stat, 0.0) + tag.stat_modifiers[stat]
	return out


## Base proc_effects concatenated with every tag's proc_effects.
func effective_proc_effects() -> Array:
	var out: Array = []
	if base != null:
		out.append_array(base.proc_effects)
	for tag in tags:
		out.append_array(tag.proc_effects)
	return out


## Base conditional_modifiers concatenated with every tag's conditional_modifiers.
func effective_conditional_modifiers() -> Array:
	var out: Array = []
	if base != null:
		out.append_array(base.conditional_modifiers)
	for tag in tags:
		out.append_array(tag.conditional_modifiers)
	return out


# --- Riders (rarity-gated behavior) ---

## Riders whose min_rarity this instance meets — the single enforcement point of the rarity gate.
## Everything downstream (stack_bonus, granted_innate_spells) reads only through here.
func effective_riders() -> Array:
	var out: Array = []
	for rider in riders:
		if rider != null and int(rarity) >= int(rider.min_rarity):
			out.append(rider)
	return out


## Total flat stacks added to STACK-policy statuses this item's attacks apply (Σ StackBonusRider) —
## more turns / a longer ramp. Orthogonal to potency_bonus (which raises per-tick damage instead).
func stack_bonus() -> int:
	var total := 0
	for rider in effective_riders():
		if rider is StackBonusRider:
			total += (rider as StackBonusRider).bonus_stacks
	return total


## Total flat per-stack tick bonus PotencyRiders add to STACK-policy statuses this item's attacks
## apply (Σ PotencyRider) — harder ticks, same duration. Orthogonal to stack_bonus.
func potency_bonus() -> int:
	var total := 0
	for rider in effective_riders():
		if rider is PotencyRider:
			total += (rider as PotencyRider).potency_bonus
	return total


## Spells granted directly to the item's hand, bypassing prep slots (from InnateSpellRider).
func granted_innate_spells() -> Array:
	var out: Array = []
	for rider in effective_riders():
		if rider is InnateSpellRider:
			var spell := (rider as InnateSpellRider).spell
			if spell != null:
				out.append(spell)
	return out


# --- Mutation API (code / debug entry points — no loot roll, no UI this pass) ---

func add_tag(tag) -> void:
	if tag != null:
		tags.append(tag)


func add_rider(rider) -> void:
	if rider != null:
		riders.append(rider)


## Smithing: power only. Raises the upgrade level; each level adds AttackData.upgrade_scale power
## per attack at hit time (see smith_power_bonus / Player.weapon_context_for).
func smith(levels: int = 1) -> void:
	upgrade_level += levels


## Rarity: scaling only. Sets the tier (RARITY_SCALING coefficient bonus).
func set_rarity(new_rarity: Enums.Rarity) -> void:
	rarity = new_rarity


# --- Serialization ---

func to_dict() -> Dictionary:
	var tag_paths: Array[String] = []
	for tag in tags:
		if tag != null and tag.resource_path != "":
			tag_paths.append(tag.resource_path)
	var rider_paths: Array[String] = []
	for rider in riders:
		if rider != null and rider.resource_path != "":
			rider_paths.append(rider.resource_path)
	return {
		"base": base.resource_path if base != null else "",
		"upgrade_level": upgrade_level,
		"rarity": int(rarity),
		"tags": tag_paths,
		"riders": rider_paths,
	}


## Rebuilds an instance from to_dict() output. Returns null if the base path no longer loads.
static func from_dict(d: Dictionary) -> ItemInstance:
	var base_path: String = d.get("base", "")
	if base_path.is_empty():
		return null
	var base_data := load(base_path) as EquipmentData
	if base_data == null:
		return null
	var inst := ItemInstance.new(base_data)
	inst.upgrade_level = int(d.get("upgrade_level", 0))
	inst.rarity = int(d.get("rarity", Enums.Rarity.COMMON)) as Enums.Rarity
	for tag_path in d.get("tags", []):
		var tag := load(tag_path)
		if tag != null:
			inst.tags.append(tag)
	# Legacy saves predate riders and have no "riders" key — .get() defaults to empty.
	for rider_path in d.get("riders", []):
		var rider := load(rider_path)
		if rider != null:
			inst.riders.append(rider)
	return inst
