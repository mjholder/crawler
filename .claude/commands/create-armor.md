---
name: create-armor
description: Interactive questionnaire to create a new EquipmentData .tres file (armor, ring, or off-slot piece) for the crawler roguelike. Saves to resources/equipment/armor/ or resources/equipment/rings/. Uses plate armor sprites as defaults.
model: claude-haiku-4-5-20251001
---

# Create Armor

Generate a valid `EquipmentData` `.tres` resource. Ask each group, then write the file.

## Enum reference

```
Stat:  STR=0  DEF=1  CON=2  AGI=3  SPI=4  LCK=5
Slot:  HANDS=1  FEET=2  LEGS=3  TORSO=4  HEAD=5
```

## Known UIDs — embed verbatim, never fabricate or modify

```
equipment_data.gd           uid://bfd1xsly2100j   path: res://scripts/equipment_data.gd
heal_effect.gd              uid://bt5lde7yv85qi   path: res://scripts/heal_effect.gd
conditional_modifier.gd     uid://bhek47yavbcbu   path: res://scripts/conditional_modifier.gd
paper_doll/chest.png        uid://bp4ynl7211xeq   path: res://assets/sprites/paper_doll/chest.png
paper_doll/helmet.png       uid://blnqqe2hhfitm   path: res://assets/sprites/paper_doll/helmet.png
paper_doll/legs.png         uid://8wbmtefgqsr3    path: res://assets/sprites/paper_doll/legs.png
paper_doll/arms_right.png   uid://bbmyalks2b35f   path: res://assets/sprites/paper_doll/arms_right.png
paper_doll/arms_left.png    uid://cb4riwpblydkc   path: res://assets/sprites/paper_doll/arms_left.png
paper_doll/boots.png        uid://dm5bed4awfx2t   path: res://assets/sprites/paper_doll/boots.png
```

## Slot → paper doll mapping

| Slot  | int | paper_doll_front | paper_doll_back |
|-------|-----|-----------------|-----------------|
| HANDS | 1   | arms_left.png   | arms_right.png  |
| FEET  | 2   | boots.png       | —               |
| LEGS  | 3   | legs.png        | —               |
| TORSO | 4   | chest.png       | —               |
| HEAD  | 5   | helmet.png      | —               |
| RING  | is_ring=true | — (no paper doll) | — |

## Existing reusable on-equip effects

```
res://resources/effects/heal_25_flat.tres
res://resources/effects/heal_25pct_max.tres
res://resources/effects/buffs/buff_str_20_3t.tres
res://resources/effects/buffs/buff_def_20_permanent.tres
```

## Questionnaire

**Group 1 — Identity**
Name and one-sentence description?

**Group 2 — Slot**
Slot: HANDS / FEET / LEGS / TORSO / HEAD / RING? [TORSO]

**Group 3 — Stats**
Stat modifiers? e.g. "DEF+10" or "DEF+8 AGI+5" or none [DEF+10]

**Group 4 — Paper doll**
Use the default paper doll sprite for this slot? [yes]
If no: enter the full res:// path to the sprite.

**Group 5 — Effects**
Any on-equip effects? Options:
- heal_25_flat, heal_25pct_max (healing)
- buff_str_20_3t, buff_def_20_permanent (stat buffs)
- Describe a custom heal amount (e.g. "heal 10")
Or none. [none]

Any conditional modifiers (e.g. "+20 STR while HP < 50%")? [none]
Format: "STAT+amount while EXPRESSION" where EXPRESSION uses: health, max_health, strength, defense, constitution, agility, spirit, luck

**Group 6 — Mage fields** (skip / press enter if not a mage item)
- spell_cost_multiplier (e.g. 0.8 = 20% cheaper spells)?
- bonus_prep_slots (extra spell slots)?
- bonus_mana_regen (extra mana per turn)?

**Group 7 — Price**
Price in gold? [40]

## Output format

Rules:
1. **No uid on [gd_resource] header** — Godot assigns on first import.
2. **Use UIDs from the table verbatim** for known resources.
3. **RING type**: omit `slot =` line, add `is_ring = true`.
4. **HANDS slot**: emit both `paper_doll_front` (arms_left) and `paper_doll_back` (arms_right).
5. **On-equip effects**: use existing .tres reference if available; otherwise inline a sub_resource. If a `StatusData` is ever used here it must be wrapped in a `StatusEffect` sub_resource — bare `StatusData` references are silently skipped because `StatusData` does not extend `Effect`.
6. **Conditional modifiers**: always inline as sub_resource.
7. **Omit empty arrays** — don't emit `on_equip_effects = Array[Resource]([])` if empty.
8. **Omit mage fields** if all are default (0.0 / 0 / 0.0).

### Template (TORSO, DEF+10, default chest sprite, no extras)

```
[gd_resource type="Resource" script_class="EquipmentData" format=3]

[ext_resource type="Script" uid="uid://bfd1xsly2100j" path="res://scripts/equipment_data.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://bp4ynl7211xeq" path="res://assets/sprites/paper_doll/chest.png" id="2_doll"]

[resource]
script = ExtResource("1_script")
item_name = "ARMOR NAME"
description = "DESCRIPTION"
paper_doll_front = ExtResource("2_doll")
stat_modifiers = {
1: 10.0
}
slot = 4
price = 40
```

### On-equip effects using existing resource

```
[ext_resource type="Resource" path="res://resources/effects/heal_25_flat.tres" id="3_heal"]

[resource]
...
on_equip_effects = Array[Resource]([ExtResource("3_heal")])
```

### Custom heal on-equip (inline sub_resource)

```
[ext_resource type="Script" uid="uid://bt5lde7yv85qi" path="res://scripts/heal_effect.gd" id="3_heal_script"]

[sub_resource type="Resource" id="HealEffect_equip"]
script = ExtResource("3_heal_script")
heal_expression = "10"

[resource]
...
on_equip_effects = Array[Resource]([SubResource("HealEffect_equip")])
```

### Conditional modifier (inline sub_resource)

```
[ext_resource type="Script" uid="uid://bhek47yavbcbu" path="res://scripts/conditional_modifier.gd" id="4_cmod"]

[sub_resource type="Resource" id="CM_str_low_hp"]
script = ExtResource("4_cmod")
stat = 0
amount_expression = "20"
guard_expression = "health < max_health * 0.5"

[resource]
...
conditional_modifiers = Array[Resource]([SubResource("CM_str_low_hp")])
```

### Ring (no slot, is_ring = true, no paper doll)

```
[gd_resource type="Resource" script_class="EquipmentData" format=3]

[ext_resource type="Script" uid="uid://bfd1xsly2100j" path="res://scripts/equipment_data.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
item_name = "RING NAME"
description = "DESCRIPTION"
is_ring = true
stat_modifiers = {
0: 5.0
}
price = 100
```

## Save path

- Standard armor: `resources/equipment/armor/<snake_name>.tres`
- Mage/light armor: `resources/equipment/armor/mage/<snake_name>.tres`
- Rings: `resources/equipment/rings/<snake_name>.tres`

After writing the file, confirm the path and ask if the user wants to create another piece.
