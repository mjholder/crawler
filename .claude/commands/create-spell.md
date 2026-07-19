---
name: create-spell
description: Interactive questionnaire to create a new SpellData .tres and optionally a TomeData .tres for the crawler roguelike. Saves to resources/spells/ and resources/tomes/.
model: claude-haiku-4-5-20251001
---

# Create Spell

Generate a `SpellData` `.tres`, and optionally a `TomeData` `.tres` that wraps it. Ask each group, then write the file(s).

## Enum reference

```
TargetMode: SINGLE_ENEMY=0  ALL_ENEMIES=1  SELF=2
```

## Known UIDs

```
status_data.gd    uid://b6e1sgjh81xns   path: res://scripts/status_data.gd
damage_effect.gd  uid://drp2lj1h0sptk   path: res://scripts/damage_effect.gd
status_effect.gd  uid://csghuvkgsslk4   path: res://scripts/status_effect.gd
```

## Existing reusable effects

```
Damage:
  res://resources/effects/damage_40_flat.tres       — 40 flat damage
  res://resources/effects/damage_str_half.tres      — STR * 0.5 damage
  res://resources/effects/damage_spi_half.tres      — SPI * 0.5 damage

Healing:
  res://resources/effects/heal_25_flat.tres         — heal 25 HP
  res://resources/effects/heal_25pct_max.tres       — heal 25% max HP

Statuses (apply to target):
  res://resources/effects/statuses/poison.tres      — 3 damage/turn, 3 turns
  res://resources/effects/statuses/bleed.tres
  res://resources/effects/statuses/stun.tres        — prevents action
  res://resources/effects/statuses/regen.tres       — heals each turn

Buffs (apply to self):
  res://resources/effects/buffs/buff_str_20_3t.tres        — +20 STR, 3 turns
  res://resources/effects/buffs/buff_def_20_permanent.tres — +20 DEF, permanent
```

If the user wants a new status not in the list, **create a new StatusData .tres** first. See "Creating a new status" below.

## Creating new effects

Effect expressions share the same variable set:
`strength`, `defense`, `constitution`, `agility`, `spirit`, `luck`, `max_health`, `health`

**Inline sub_resource** — use when the effect is unique to this spell (never reused).
**Standalone .tres file** — use when the effect might appear on multiple spells or attacks. Write it first, then reference it as an ext_resource. Save to `resources/effects/<snake_name>.tres`.

Script paths (path-only, no UIDs):
```
res://scripts/damage_effect.gd
res://scripts/heal_effect.gd
res://scripts/buff_effect.gd
```
Stat int: STR=0  DEF=1  CON=2  AGI=3  SPI=4  LCK=5

### Standalone DamageEffect

```
[gd_resource type="Resource" script_class="DamageEffect" format=3]

[ext_resource type="Script" path="res://scripts/damage_effect.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
damage_expression = "spirit * 0.75"
```

### Standalone HealEffect

```
[gd_resource type="Resource" script_class="HealEffect" format=3]

[ext_resource type="Script" path="res://scripts/heal_effect.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
heal_expression = "spirit * 2 + 10"
```

### Standalone BuffEffect

```
[gd_resource type="Resource" script_class="BuffEffect" format=3]

[ext_resource type="Script" path="res://scripts/buff_effect.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
stat = 4
amount_expression = "15"
duration = 3
```
`duration = -1` for permanent (BuffEffect uses -1, not 0, for permanent).

## Creating a new status

When the user wants a status that doesn't exist, write a `StatusData .tres` at `resources/effects/statuses/<snake_name>.tres` **before** the spell file, then reference it as a path-only ext_resource.

StatusData uses the UIDs from the Known UIDs table for its script references. Effect scripts within it are path-only.

StatusData fields:
- `tag` — StringName identifying the status; use `&"name"` syntax
- `display_name` — shown in UI
- `duration` — turns active; 0 = permanent
- `prevents_action` — true for stun-like effects
- `stat_modifiers` — `{ Stat_int: float }` passive modifier while active
- `on_apply`, `on_tick`, `on_expire` — each an inline sub_resource (DamageEffect, HealEffect, or BuffEffect)
- `stack_policy` — REFRESH=0 (reset duration), STACK=1 (multiple instances), MAX_DURATION=2 (keep longest)

### Damage-on-tick (poison / bleed style)

```
[gd_resource type="Resource" script_class="StatusData" format=3]

[ext_resource type="Script" uid="uid://b6e1sgjh81xns" path="res://scripts/status_data.gd" id="1_script"]
[ext_resource type="Script" path="res://scripts/damage_effect.gd" id="2_dmg_script"]

[sub_resource type="Resource" id="Tick_1"]
script = ExtResource("2_dmg_script")
damage_expression = "3"

[resource]
script = ExtResource("1_script")
tag = &"burn"
display_name = "Burn"
duration = 4
on_tick = SubResource("Tick_1")
stack_policy = 0
```

### Heal-on-tick (regen style)

Replace damage script + sub_resource with:
```
[ext_resource type="Script" path="res://scripts/heal_effect.gd" id="2_heal_script"]

[sub_resource type="Resource" id="Tick_1"]
script = ExtResource("2_heal_script")
heal_expression = "5"
```

### Prevents-action (stun style) — no tick script needed

```
[resource]
script = ExtResource("1_script")
tag = &"stun"
display_name = "Stun"
duration = 1
prevents_action = true
stack_policy = 0
```

### Passive stat debuff — no tick script needed

```
[resource]
script = ExtResource("1_script")
tag = &"weakened"
display_name = "Weakened"
duration = 3
stat_modifiers = {
0: -15.0
}
stack_policy = 0
```

### On-apply or on-expire burst (e.g. explodes on expiry)

```
[ext_resource type="Script" path="res://scripts/damage_effect.gd" id="2_dmg_script"]

[sub_resource type="Resource" id="Expire_1"]
script = ExtResource("2_dmg_script")
damage_expression = "10"

[resource]
...
on_expire = SubResource("Expire_1")
```

Any combination of `on_apply`, `on_tick`, `on_expire` is valid — add sub_resources for each that's needed.

## Questionnaire

**Group 1 — Identity**
Spell name and description?

**Group 2 — Mechanics**
- Target mode: SINGLE_ENEMY / ALL_ENEMIES / SELF? [SINGLE_ENEMY]
- Mana cost? [5]
- Cooldown — player turns until reusable, 0 = none? [0]
  (Use ≥2 to actually gate; `1` is a no-op given one action per hand per turn.)

**Group 3 — Effects**
Effects to apply (comma-separated from the list above, or describe a new one)?
Examples: "damage_spi_half, poison" or "heal 30 flat" or "buff STR+15 for 2 turns"
[damage_spi_half]

**Group 4 — Tome**
Also create a Tome for this spell? [no]
If yes: Tome name, description, price (gold value)?

## Output format

Rules:
1. **No uid on [gd_resource] header**.
2. **Use path-only ext_resource references** for spell_data.gd and effect scripts (no UIDs for these — they're not in the known-UID table).
3. **Multiple effects**: give each an ext_resource with sequential IDs (2_eff1, 3_eff2, …); all go in the `effects = Array[Resource]([...])`.
4. **Custom / inline effects**: add the effect script as an ext_resource, then define a sub_resource before [resource].
5. **StringNames** use `&""` syntax if needed (e.g. for status tags).
6. **Cooldown**: add `cooldown = N` (int) after `target_mode` **only when N > 0**; omit the line for the default 0 (Godot drops default values).

### Template (single existing effect)

```
[gd_resource type="Resource" script_class="SpellData" format=3]

[ext_resource type="Script" path="res://scripts/spell_data.gd" id="1_script"]
[ext_resource type="Resource" path="res://resources/effects/damage_spi_half.tres" id="2_effect"]

[resource]
script = ExtResource("1_script")
spell_name = "SPELL NAME"
description = "DESCRIPTION"
mana_cost = 5.0
target_mode = 0
effects = Array[Resource]([ExtResource("2_effect")])
```

### With multiple effects (including a status)

**Statuses cannot go directly in `effects` — they must be wrapped in a `StatusEffect` sub_resource.** A bare `StatusData` reference is silently skipped because `StatusData` does not extend `Effect`.

```
[ext_resource type="Script" uid="uid://csghuvkgsslk4" path="res://scripts/status_effect.gd" id="2_seff"]
[ext_resource type="Resource" path="res://resources/effects/damage_spi_half.tres" id="3_dmg"]
[ext_resource type="Resource" path="res://resources/effects/statuses/poison.tres" id="4_poison"]

[sub_resource type="Resource" id="StatusEffect_poison"]
script = ExtResource("2_seff")
status_data = ExtResource("4_poison")

[resource]
...
effects = Array[Resource]([ExtResource("3_dmg"), SubResource("StatusEffect_poison")])
```

### With inline custom heal effect

```
[ext_resource type="Script" path="res://scripts/heal_effect.gd" id="2_heal_script"]

[sub_resource type="Resource" id="HealEffect_custom"]
script = ExtResource("2_heal_script")
heal_expression = "30"

[resource]
...
effects = Array[Resource]([SubResource("HealEffect_custom")])
```

### With inline custom buff effect

```
[ext_resource type="Script" path="res://scripts/buff_effect.gd" id="2_buff_script"]

[sub_resource type="Resource" id="BuffEffect_custom"]
script = ExtResource("2_buff_script")
stat = 0
amount_expression = "15"
duration = 2

[resource]
...
effects = Array[Resource]([SubResource("BuffEffect_custom")])
```

### TomeData template (write as a second file)

```
[gd_resource type="Resource" script_class="TomeData" format=3]

[ext_resource type="Script" path="res://scripts/tome_data.gd" id="1_script"]
[ext_resource type="Resource" path="res://resources/spells/SPELL_FILE_NAME.tres" id="2_spell"]

[resource]
script = ExtResource("1_script")
item_name = "TOME NAME"
description = "DESCRIPTION"
price = 30
spell = ExtResource("2_spell")
```

## Save paths

Write files in this order:
1. New standalone effect .tres files (if any): `resources/effects/<snake_name>.tres`
2. New status .tres files (if any): `resources/effects/statuses/<snake_name>.tres`
3. Spell: `resources/spells/<snake_name>.tres`
4. Tome (if requested): `resources/tomes/tome_of_<snake_name>.tres`

After writing all files, confirm each path and ask if the user wants to create another spell or different content.
