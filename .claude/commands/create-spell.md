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

## Custom effect expressions

If the user wants something not in the list above, generate an inline sub_resource:

```
DamageEffect:  damage_expression uses: strength, defense, constitution, agility, spirit, luck, max_health, health
HealEffect:    heal_expression uses same variables
BuffEffect:    stat (Stat int), amount_expression, duration (turns; 0 = permanent)

Stat int: STR=0  DEF=1  CON=2  AGI=3  SPI=4  LCK=5
```

Script paths for inline effects:
```
res://scripts/damage_effect.gd
res://scripts/heal_effect.gd
res://scripts/buff_effect.gd
```

## Questionnaire

**Group 1 — Identity**
Spell name and description?

**Group 2 — Mechanics**
- Target mode: SINGLE_ENEMY / ALL_ENEMIES / SELF? [SINGLE_ENEMY]
- Mana cost? [5]

**Group 3 — Effects**
Effects to apply (comma-separated from the list above, or describe a new one)?
Examples: "damage_spi_half, poison" or "heal 30 flat" or "buff STR+15 for 2 turns"
[damage_spi_half]

**Group 4 — Tome**
Also create a Tome for this spell? [no]
If yes: Tome name, description, gold value?

## Output format

Rules:
1. **No uid on [gd_resource] header**.
2. **Use path-only ext_resource references** for spell_data.gd and effect scripts (no UIDs for these — they're not in the known-UID table).
3. **Multiple effects**: give each an ext_resource with sequential IDs (2_eff1, 3_eff2, …); all go in the `effects = Array[Resource]([...])`.
4. **Custom / inline effects**: add the effect script as an ext_resource, then define a sub_resource before [resource].
5. **StringNames** use `&""` syntax if needed (e.g. for status tags).

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

### With multiple effects

```
[ext_resource type="Resource" path="res://resources/effects/damage_spi_half.tres" id="2_dmg"]
[ext_resource type="Resource" path="res://resources/effects/statuses/poison.tres" id="3_poison"]

[resource]
...
effects = Array[Resource]([ExtResource("2_dmg"), ExtResource("3_poison")])
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
gold_value = 30
spell = ExtResource("2_spell")
```

## Save paths

- Spell: `resources/spells/<snake_name>.tres`
- Tome: `resources/tomes/tome_of_<snake_name>.tres`

After writing, confirm path(s) and ask if the user wants to create another spell or different content.
