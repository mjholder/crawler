---
name: create-weapon
description: Interactive questionnaire to create a new WeaponData .tres file for the crawler roguelike. Saves to resources/equipment/weapons/. Use battle_axe sprites as default.
model: claude-haiku-4-5-20251001
---

# Create Weapon

Generate a valid `WeaponData` `.tres` resource for this Godot 4.6 roguelike. Ask each group of questions, then write the file.

## Enum reference

```
Stat:  STR=0  DEF=1  CON=2  AGI=3  SPI=4  LCK=5
Slot:  WEAPON=0  OFFHAND=6
```

## Known UIDs — embed verbatim, never fabricate or modify

```
weapon_data.gd              uid://bkgb8ckvvwyft   path: res://scripts/weapon_data.gd
proc_def.gd                 uid://bhd611piw5n14   path: res://scripts/proc_def.gd
status_effect.gd            uid://csghuvkgsslk4   path: res://scripts/status_effect.gd
scenes/weapon.tscn          uid://bkwtkj4t1b4se   path: res://scenes/weapon.tscn
battle_axe/windup.png       uid://drbota0c0gcff   path: res://assets/sprites/weapons/battle_axe/windup.png
battle_axe/swing.png        uid://dbv4prm15qp3l   path: res://assets/sprites/weapons/battle_axe/swing.png
battle_axe/idle.png         uid://bx8qgjpp08r0n   path: res://assets/sprites/weapons/battle_axe/idle.png
battle_axe/icon.png         uid://bj083b7w7egw7   path: res://assets/sprites/weapons/battle_axe/icon.png
effects/statuses/poison.tres uid://b7kqmoyng5ydc  path: res://resources/effects/statuses/poison.tres
```

## Existing attacks (reuse by reference)

```
res://resources/attacks/slash.tres   — single enemy, STR/2 damage
res://resources/attacks/cleave.tres  — all enemies, STR/2 damage
res://resources/attacks/brace.tres   — self, applies STR buff
```

## Existing proc-able effects

```
Statuses: res://resources/effects/statuses/poison.tres (uid://b7kqmoyng5ydc)
          res://resources/effects/statuses/bleed.tres
          res://resources/effects/statuses/stun.tres
          res://resources/effects/statuses/regen.tres
Buffs:    res://resources/effects/buffs/buff_str_20_3t.tres
          res://resources/effects/buffs/buff_def_20_permanent.tres
```

## Questionnaire

Ask these groups in order. Show defaults in [brackets]. Wait for all answers before generating.

**Group 1 — Identity**
What is the weapon's name, and give it a one-line description?
(e.g. "Thunder Maul — a two-handed warhammer crackling with storm energy")

**Group 2 — Slot & handedness**
- Slot: WEAPON (0) or OFFHAND (6)? [WEAPON]
- Two-handed? [no]

**Group 3 — Combat**
- Attacks to attach — comma-separated from: slash, cleave, brace, or none [slash, cleave]
- Innate spells (res://resources/spells/ file names, or none)? [none]

**Group 4 — Stats**
Stat modifiers? e.g. "STR+10 AGI-5" or none [STR+10]

**Group 5 — Procs**
On-hit procs? For each: trigger name, chance (0.0–1.0), effect name. Or none. [none]
Available triggers: player_attack_hit, player_attack_miss, enemy_attack_hit, enemy_attack_miss
Example: "player_attack_hit 0.25 poison"

**Group 6 — Price**
Price in gold? [80]

**Group 7 — Sprites**
Sprite set: type "battle_axe" to use default sprites, or enter a custom folder path.
Custom path format: res://assets/sprites/weapons/<folder>/
Folder must contain: idle.png, swing.png, windup.png, icon.png
[battle_axe]

## Output format

After collecting answers, generate the `.tres` content. Rules:

1. **No uid on the [gd_resource] header** — Godot assigns it on first import.
2. **Use UIDs from the table above verbatim** for known resources. For custom sprite paths, omit the uid attribute (path-only reference).
3. **SpriteFrames is always an inline sub_resource** — never external.
4. **windup frame** uses an AtlasTexture sub_resource wrapping the windup texture.
5. **StringNames use &"" syntax** — e.g. `name: &"idle"`, `trigger = &"player_attack_hit"`.
6. **Typed arrays** — attacks and proc_effects use `Array[Resource]([...])` syntax.
7. **Proc effects** — each proc needs two sub_resources: one StatusEffect wrapping the effect data, one ProcDef referencing it.
8. **Readable local IDs** — use names like `id="1_script"`, `id="2_windup"` (unique within the file).

### Template (battle_axe sprites, no procs, slash+cleave attacks)

```
[gd_resource type="Resource" script_class="WeaponData" format=3]

[ext_resource type="Script" uid="uid://bkgb8ckvvwyft" path="res://scripts/weapon_data.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://drbota0c0gcff" path="res://assets/sprites/weapons/battle_axe/windup.png" id="2_windup"]
[ext_resource type="Texture2D" uid="uid://dbv4prm15qp3l" path="res://assets/sprites/weapons/battle_axe/swing.png" id="3_swing"]
[ext_resource type="Texture2D" uid="uid://bx8qgjpp08r0n" path="res://assets/sprites/weapons/battle_axe/idle.png" id="4_idle"]
[ext_resource type="Texture2D" uid="uid://bj083b7w7egw7" path="res://assets/sprites/weapons/battle_axe/icon.png" id="5_icon"]
[ext_resource type="PackedScene" uid="uid://bkwtkj4t1b4se" path="res://scenes/weapon.tscn" id="6_scene"]
[ext_resource type="Resource" path="res://resources/attacks/slash.tres" id="7_slash"]
[ext_resource type="Resource" path="res://resources/attacks/cleave.tres" id="8_cleave"]

[sub_resource type="AtlasTexture" id="AtlasTexture_windup"]
atlas = ExtResource("2_windup")
region = Rect2(0, 0, 480, 270)

[sub_resource type="SpriteFrames" id="SpriteFrames_main"]
animations = [{
"frames": [{
"duration": 1.0,
"texture": ExtResource("4_idle")
}],
"loop": true,
"name": &"idle",
"speed": 5.0
}, {
"frames": [{
"duration": 1.0,
"texture": ExtResource("3_swing")
}],
"loop": false,
"name": &"swing",
"speed": 5.0
}, {
"frames": [{
"duration": 1.0,
"texture": SubResource("AtlasTexture_windup")
}],
"loop": true,
"name": &"wind_up",
"speed": 5.0
}]

[resource]
script = ExtResource("1_script")
attacks = Array[Resource]([ExtResource("7_slash"), ExtResource("8_cleave")])
item_name = "WEAPON NAME"
description = "DESCRIPTION"
sprite_frames = SubResource("SpriteFrames_main")
paper_doll_front = ExtResource("5_icon")
stat_modifiers = {
0: 10.0
}
slot = 0
is_two_handed = false
proc_effects = Array[Resource]([])
scene = ExtResource("6_scene")
price = 80
```

### Additions for proc effects (add before [resource], update proc_effects line)

Add these ext_resources if not already present (poison example):
```
[ext_resource type="Script" uid="uid://bhd611piw5n14" path="res://scripts/proc_def.gd" id="9_procd"]
[ext_resource type="Script" uid="uid://csghuvkgsslk4" path="res://scripts/status_effect.gd" id="10_seff"]
[ext_resource type="Resource" uid="uid://b7kqmoyng5ydc" path="res://resources/effects/statuses/poison.tres" id="11_poi"]
```

Add sub_resources:
```
[sub_resource type="Resource" id="StatusEffect_poison"]
script = ExtResource("10_seff")
status_data = ExtResource("11_poi")

[sub_resource type="Resource" id="ProcDef_poison_on_hit"]
script = ExtResource("9_procd")
trigger = &"player_attack_hit"
chance_expression = "0.25"
effect = SubResource("StatusEffect_poison")
```

Update resource block:
```
proc_effects = Array[Resource]([SubResource("ProcDef_poison_on_hit")])
```

For effects with no known uid (bleed, stun, regen), omit the uid attribute on their ext_resource line.

## Save path

`resources/equipment/weapons/<snake_case_name>.tres`
For mage/caster weapons: `resources/equipment/weapons/mage/<name>.tres`

After writing the file, confirm the path and ask if the user wants to create another weapon or a different content type.
