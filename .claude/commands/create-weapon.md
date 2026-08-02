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
attack_data.gd              uid://ccpry8dqx7266   path: res://scripts/attack_data.gd
status_data.gd              uid://b6e1sgjh81xns   path: res://scripts/status_data.gd
damage_effect.gd            uid://drp2lj1h0sptk   path: res://scripts/damage_effect.gd
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

If the user wants an attack that doesn't exist, **create a new AttackData .tres** first, then reference it in the weapon. See "Creating a new attack" below.

## Existing proc-able effects

```
Statuses: res://resources/effects/statuses/poison.tres (uid://b7kqmoyng5ydc)
          res://resources/effects/statuses/bleed.tres
          res://resources/effects/statuses/stun.tres
          res://resources/effects/statuses/regen.tres
Buffs:    res://resources/effects/buffs/buff_str_20_3t.tres
          res://resources/effects/buffs/buff_def_20_permanent.tres
Damage:   res://resources/effects/damage_40_flat.tres
          res://resources/effects/damage_str_half.tres
```

Any effect type (status, buff, damage, heal) can be a proc target. For anything not in the list, see the "Creating new effects" and "Creating a new status" sections below.

## Questionnaire

Ask these groups in order. Show defaults in [brackets]. Wait for all answers before generating.

**Group 1 — Identity**
What is the weapon's name, and give it a one-line description?
(e.g. "Thunder Maul — a two-handed warhammer crackling with storm energy")

**Group 2 — Slot & handedness**
- Slot: WEAPON (0) or OFFHAND (6)? [WEAPON]
- Two-handed? [no]

**Group 3 — Combat**
- Attacks to attach — comma-separated from the existing list, or describe new attacks to create [slash, cleave]
  - For each new attack: name, target (single/all/self), cooldown (player turns until reusable, 0 = none), and what it does.
    - Cooldown: use ≥2 to actually gate; `1` is a no-op given one action per hand per turn.
    - **Damage attacks do NOT get a hand-written formula.** Every weapon hit uses the one uniform
      expression `power * coeff + scale * scaling`, which reads the weapon's damage (Group 4) and the
      bearer's scaling stat. To make one attack hit harder/softer than another on the same weapon, set
      its **shape knob** `power_coefficient` (float, default `1.0`; 1.3 = +30% of flat power). Ask only
      if the user wants a non-default shape — otherwise leave it at 1.0 and omit the line.
- Innate spells (res://resources/spells/ file names, or none)? [none]

**Group 4 — Weapon damage (the two anatomy axes)**
Weapon damage is authored on the weapon, not baked into attacks — one change re-tunes all its attacks.
- `power` — flat damage floor (smithing moves this) [12]
- `scaling` — stat coefficient (rarity moves this) [0.5]
- `scaling_stat` — the ONE stat this weapon scales: STR=0, AGI=3, SPI=4 (one weapon, one stat) [STR]
  - STR for axes/maces/swords, AGI for daggers/rapiers, SPI for caster weapons. Daggers: low `power`,
    equal `scaling`, payoff in riders (bleed/poison), not raw numbers.

**Group 5 — Stats**
Stat modifiers? e.g. "STR+10 AGI-5" or none [STR+10]

**Group 6 — Procs**
On-hit procs? For each: trigger name, chance (0.0–1.0), effect (existing name or describe new), and target (enemy or wielder). Or none. [none]
Available triggers: player_attack_hit, player_attack_miss, enemy_attack_hit, enemy_attack_miss
Example: "player_attack_hit 0.25 poison (enemy)" or "player_attack_hit 1.0 self-damage 20 flat (wielder)"

**Group 7 — Price**
Price in gold? [80]

**Group 8 — Sprites**
Sprite set: type "battle_axe" to use default sprites, or enter a custom folder path.
Custom path format: res://assets/sprites/weapons/<folder>/
Folder must contain: idle.png, swing.png, windup.png, icon.png
[battle_axe]

## Creating new effects

Effect expressions share a variable set: `strength`, `defense`, `constitution`, `agility`,
`spirit`, `luck`, `max_health`, `health`.

**Weapon basic-attack damage uses the uniform ratio form, not a stat formula.** A weapon damage
effect is always:
```
damage_expression = "power * coeff + scale * scaling"
```
where `power`/`scaling` come from the weapon (Group 4), `scale` is the bearer's scaling stat, and
`coeff` is the attack's `power_coefficient` (default 1.0). Differentiate attacks via that knob — do
**not** hand-write `strength * 0.5`. Raw stat expressions are only for non-weapon damage: spell
effects (flat authored number, no stat term) and status ticks.

**Inline sub_resource** — use when the effect is unique to this attack (never reused).
**Standalone .tres file** — use when the effect might appear on multiple attacks or spells. Write it first, then reference as a path-only ext_resource. Save to `resources/effects/<snake_name>.tres`.

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
damage_expression = "power * coeff + scale * scaling"
```

### Standalone HealEffect

```
[gd_resource type="Resource" script_class="HealEffect" format=3]

[ext_resource type="Script" path="res://scripts/heal_effect.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
heal_expression = "constitution * 2"
```

### Standalone BuffEffect

```
[gd_resource type="Resource" script_class="BuffEffect" format=3]

[ext_resource type="Script" path="res://scripts/buff_effect.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
stat = 0
amount_expression = "20"
duration = 3
```
`duration = -1` for permanent (BuffEffect uses -1, not 0, for permanent).

### Standalone AttackCoeffBuffEffect (buff the damage `coeff`)

Grants a decaying status that shifts the wielder's attack `coeff` — a "focus / empower my next
hits" lever. `mode` ADD=0 adds to `coeff` (stacks with other adds); MULTIPLY=1 scales it. Put this
on a SELF-target attack (or a proc) so it buffs the wielder.

```
[gd_resource type="Resource" script_class="AttackCoeffBuffEffect" format=3]

[ext_resource type="Script" path="res://scripts/attack_coeff_buff_effect.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
mode = 0
amount_expression = "0.3"
duration = 3
```
`mode = 0` (ADD) with `amount_expression = "0.3"` → next attacks compute `power * 1.3 + …` for the
duration. Use `mode = 1` (MULTIPLY) to scale instead. `amount_expression` may use the stat vars.

## Creating a new attack

When a requested attack isn't in the existing list, write a new `AttackData .tres` at `resources/attacks/<snake_name>.tres` **before** the weapon file. Reference it with a path-only ext_resource (no uid).

TargetMode: SINGLE_ENEMY=0, ALL_ENEMIES=1, SELF=2

**Cooldown:** add `cooldown = N` (int, player turns until reusable) after `target_mode` **only when N > 0** — omit the line for the default 0 (Godot drops default values). Use ≥2 to actually gate.

**Shape knob:** add `power_coefficient = N` (float) after `cooldown` **only when N ≠ 1.0** — omit for the
default 1.0 (Godot drops default values). This is the `coeff` in `power * coeff + scale * scaling`, the
single lever for making an attack hit harder/softer than its weapon's flat power. Don't rewrite the
damage expression to differentiate attacks — move this number.

### AttackData template (inline damage effect, single enemy)

```
[gd_resource type="Resource" script_class="AttackData" format=3]

[ext_resource type="Script" uid="uid://ccpry8dqx7266" path="res://scripts/attack_data.gd" id="1_script"]
[ext_resource type="Script" path="res://scripts/damage_effect.gd" id="2_dmg_script"]

[sub_resource type="Resource" id="DamageEffect_main"]
script = ExtResource("2_dmg_script")
damage_expression = "power * coeff + scale * scaling"

[resource]
script = ExtResource("1_script")
attack_name = "ATTACK NAME"
description = "DESCRIPTION"
target_mode = 0
effects = Array[Resource]([SubResource("DamageEffect_main")])
```

To use a standalone effect file instead, replace the script ext_resource + sub_resource with a single Resource ext_resource pointing to the .tres path, then use `ExtResource("id")` in the effects array.

Multiple effects are supported — just add more entries to `effects = Array[Resource]([...])`.

### AttackData with a status effect

**Statuses cannot go directly in `effects` — they must be wrapped in a `StatusEffect` sub_resource.** A bare `StatusData` reference is silently skipped because `StatusData` does not extend `Effect`. Pattern (using existing poison as example; omit uid if the status has no known uid):

```
[ext_resource type="Script" uid="uid://ccpry8dqx7266" path="res://scripts/attack_data.gd" id="1_script"]
[ext_resource type="Script" uid="uid://drp2lj1h0sptk" path="res://scripts/damage_effect.gd" id="2_dmg_script"]
[ext_resource type="Resource" uid="uid://b7kqmoyng5ydc" path="res://resources/effects/statuses/poison.tres" id="3_poison"]
[ext_resource type="Script" uid="uid://csghuvkgsslk4" path="res://scripts/status_effect.gd" id="4_seff"]

[sub_resource type="Resource" id="DamageEffect_main"]
script = ExtResource("2_dmg_script")
damage_expression = "power * coeff + scale * scaling"

[sub_resource type="Resource" id="StatusEffect_poison"]
script = ExtResource("4_seff")
status_data = ExtResource("3_poison")

[resource]
script = ExtResource("1_script")
attack_name = "ATTACK NAME"
description = "DESCRIPTION"
target_mode = 0
effects = Array[Resource]([SubResource("DamageEffect_main"), SubResource("StatusEffect_poison")])
```

Apply the same `StatusEffect` wrapping in `SpellData.effects` and `ConsumableData.effects` — any `effects: Array[Resource]` field on a use-action resource.

## Creating a new status

When a proc calls for a status that doesn't exist, write a `StatusData .tres` at `resources/effects/statuses/<snake_name>.tres` **before** the weapon file. Reference it with a path-only ext_resource (no uid).

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

Replace the damage script + sub_resource with:
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

### On-apply or on-expire burst

Add the appropriate sub_resource and assign it to `on_apply` or `on_expire`:
```
[sub_resource type="Resource" id="Apply_1"]
script = ExtResource("2_dmg_script")
damage_expression = "8"

[resource]
...
on_apply = SubResource("Apply_1")
```

Any combination of `on_apply`, `on_tick`, `on_expire` is valid — add sub_resources for each needed.

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
power = 12.0
scaling = 0.5
scaling_stat = 0
slot = 0
is_two_handed = false
proc_effects = Array[Resource]([])
scene = ExtResource("6_scene")
price = 80
```

`power` / `scaling` / `scaling_stat` (Group 4) are what the attack's `power * coeff + scale * scaling`
expression reads. `scaling_stat` is a Stat int (STR=0, AGI=3, SPI=4). Omit all three only for a
weapon with no basic attacks (pure spell focus). Smithing later moves `power`, rarity moves `scaling` —
author the base values here.

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

### Self-affecting proc (e.g. Vorpal Blade self-damage)

By default, `player_attack_hit` procs apply their effect to each enemy target. To apply to the **wielder** instead — e.g. a weapon that hurts you on every swing — set `apply_to_owner = true` on the ProcDef. The effect fires once per attack, not once per enemy:

```
[sub_resource type="Resource" id="ProcDef_self_damage"]
script = ExtResource("9_procd")
trigger = &"player_attack_hit"
apply_to_owner = true
effect = SubResource("DamageEffect_self")
```

When `apply_to_owner` is omitted (or `false`), the proc targets enemies as normal.

## Save path

Write files in this order:
1. New standalone effect .tres files (if any): `resources/effects/<snake_name>.tres`
2. New status .tres files (if any): `resources/effects/statuses/<snake_name>.tres`
3. New attack .tres files (if any): `resources/attacks/<snake_name>.tres`
4. Weapon: `resources/equipment/weapons/<snake_case_name>.tres`
   For mage/caster weapons: `resources/equipment/weapons/mage/<name>.tres`

After writing all files, confirm each path and ask if the user wants to create another weapon or a different content type.
