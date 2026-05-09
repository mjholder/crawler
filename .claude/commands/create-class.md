---
name: create-class
description: Interactive questionnaire to create a new PlayerClassData .tres for the crawler roguelike. Saves to resources/classes/. Uses warrior equipment as defaults.
model: claude-haiku-4-5-20251001
---

# Create Class

Generate a valid `PlayerClassData` `.tres`. Ask each group, then write the file.

## Enum reference

```
Stat:  STR=0  DEF=1  CON=2  AGI=3  SPI=4  LCK=5
Slot:  WEAPON=0  HANDS=1  FEET=2  LEGS=3  TORSO=4  HEAD=5
```

## Known UIDs — embed verbatim, never fabricate or modify

```
# Scripts
player_class_data.gd  (no UID — path-only reference)
equipment_data.gd     uid://bfd1xsly2100j   path: res://scripts/equipment_data.gd
consumable_data.gd    uid://3eu536m6ee4v    path: res://scripts/consumable_data.gd
blessing_data.gd      uid://jvfhxoq8sxt2   path: res://scripts/blessing_data.gd

# Equipment resources (include uid when known, omit otherwise)
battle_axe.tres       uid://b2df62wmsyqmd  path: res://resources/equipment/weapons/battle_axe.tres
plate_chest.tres      uid://db1bvel3krb2   path: res://resources/equipment/armor/plate_chest.tres
plate_gauntlets.tres  uid://d1nvy8kmtr4df  path: res://resources/equipment/armor/plate_gauntlets.tres
plate_greaves.tres    uid://bq5o044b4yvpf  path: res://resources/equipment/armor/plate_greaves.tres
plate_sabatons.tres   uid://c3fdr75kpm7lo  path: res://resources/equipment/armor/plate_sabatons.tres
plate_helm.tres       uid://dc0j3dtvh4on8  path: res://resources/equipment/armor/plate_helm.tres
berserker_ring.tres   uid://boxig0ica641y  path: res://resources/equipment/rings/berserker_ring.tres
```

## Available starting resources

```
Weapons:     battle_axe, oak_staff (mage/)
Armor:       plate_chest, plate_helm, plate_gauntlets, plate_greaves, plate_sabatons
             leather_chest, apprentice_robes (mage/)
Rings:       berserker_ring, iron_ring
Consumables: minor_healing_potion, major_healing_potion, throwing_bomb, strength_tonic
Blessings:   battle_fury, fortitude, iron_skin, vampiric_pact, warriors_resolve, mage_armor
Spells:      magic_missile, mend, sparks
```

## Questionnaire

**Group 1 — Identity**
Class name and flavour description (one sentence)?

**Group 2 — Starting stats** (each 0–100)
STR / DEF / CON / AGI / SPI / LCK?
Reference points:
  Warrior: 70 / 55 / 55 / 40 / 30 / 45
  Mage:    30 / 35 / 35 / 45 / 70 / 45
[50 / 50 / 50 / 50 / 50 / 50]

**Group 3 — Bonus pools**
- class_health_bonus (flat HP added on top of CON; warrior=20, mage=0)? [0]
- class_mana_bonus (flat mana added on top of SPI; warrior=0, mage=10)? [0]

**Group 4 — Growth rates**
Per-level stat growth — format "STR:3 CON:2" (omit stats that don't grow)? [STR:2]

**Group 5 — Starting equipment**
- Weapon (name from Available list above)? [battle_axe]
- TORSO armor? [plate_chest]
- HEAD armor? [plate_helm]
- HANDS armor? [plate_gauntlets]
- LEGS armor? [plate_greaves]
- FEET armor? [plate_sabatons]
- Ring (name, or none)? [none]
(Enter "empty" or "none" for any slot to leave it unfilled.)

**Group 6 — Spells & mana**
- mana_regen_per_turn? [0.0]
- starting_prep_slots (spell preparation slots)? [2]
- Starting learned spells (comma-separated names, or none)? [none]
- Starting prepared spells (subset of learned, or same)? [same as learned]
- Starting tomes (comma-separated names, or none)? [none]

**Group 7 — Blessings & consumables**
- Starting blessings (comma-separated from Available list, or none)? [none]
- Starting consumables (comma-separated from Available list, or none)? [none]

## Output format

Rules:
1. **No uid on [gd_resource] header**.
2. **player_class_data.gd** — ext_resource with path only, NO uid attribute.
3. **equipment_data.gd** ext_resource is always present (it's the type arg for starting_rings typed array, even if rings are empty).
4. **consumable_data.gd and blessing_data.gd** — include only if those arrays are non-empty.
5. **Include UID on equipment ext_resources** when in the known-UID table; omit uid for custom/unknown equipment.
6. **starting_equipped** is a plain dict mapping slot int → ExtResource.
7. **Typed array syntax** for rings/consumables/blessings:
   - `Array[ExtResource("equipment_data_script_id")]([ExtResource("ring_id"), ...])`
   - `Array[ExtResource("consumable_data_script_id")]([ExtResource("consumable_id"), ...])`
   - `Array[ExtResource("blessing_data_script_id")]([ExtResource("blessing_id"), ...])`
   - The type argument is the EXT_RESOURCE ID of the *script*, not the item.
   - Even if the array is empty, if the field is present in the class use `Array[ExtResource("script_id")]([])`.
8. **Omit fields at their default** — don't emit `mana_regen_per_turn = 0.0` if 0.0, etc. Match what warrior.tres emits.
9. **growth_rates** — only include stats that have non-zero growth.
10. **starting_equipped** — omit slot keys where armor is "none"/"empty".

### Template (warrior-like, full plate + axe, one blessing, two consumables)

```
[gd_resource type="Resource" script_class="PlayerClassData" format=3]

[ext_resource type="Script" path="res://scripts/player_class_data.gd" id="1_pcd"]
[ext_resource type="Script" uid="uid://bfd1xsly2100j" path="res://scripts/equipment_data.gd" id="2_equip_script"]
[ext_resource type="Resource" uid="uid://b2df62wmsyqmd" path="res://resources/equipment/weapons/battle_axe.tres" id="3_weapon"]
[ext_resource type="Script" uid="uid://3eu536m6ee4v" path="res://scripts/consumable_data.gd" id="4_cons_script"]
[ext_resource type="Script" uid="uid://jvfhxoq8sxt2" path="res://scripts/blessing_data.gd" id="5_bless_script"]
[ext_resource type="Resource" path="res://resources/blessings/warriors_resolve.tres" id="6_blessing"]
[ext_resource type="Resource" path="res://resources/equipment/consumables/major_healing_potion.tres" id="7_potion"]
[ext_resource type="Resource" path="res://resources/equipment/consumables/throwing_bomb.tres" id="8_bomb"]
[ext_resource type="Resource" uid="uid://db1bvel3krb2" path="res://resources/equipment/armor/plate_chest.tres" id="9_chest"]
[ext_resource type="Resource" uid="uid://d1nvy8kmtr4df" path="res://resources/equipment/armor/plate_gauntlets.tres" id="10_gaunt"]
[ext_resource type="Resource" uid="uid://bq5o044b4yvpf" path="res://resources/equipment/armor/plate_greaves.tres" id="11_greaves"]
[ext_resource type="Resource" uid="uid://c3fdr75kpm7lo" path="res://resources/equipment/armor/plate_sabatons.tres" id="12_sabs"]
[ext_resource type="Resource" uid="uid://dc0j3dtvh4on8" path="res://resources/equipment/armor/plate_helm.tres" id="13_helm"]

[resource]
script = ExtResource("1_pcd")
class_name_text = "CLASS NAME"
description = "FLAVOUR DESCRIPTION"
strength = 70.0
defense = 55.0
constitution = 55.0
agility = 40.0
spirit = 30.0
luck = 45.0
class_health_bonus = 20.0
growth_rates = {
0: 3.0,
2: 2.0
}
starting_equipped = {
0: ExtResource("3_weapon"),
1: ExtResource("10_gaunt"),
2: ExtResource("12_sabs"),
3: ExtResource("11_greaves"),
4: ExtResource("9_chest"),
5: ExtResource("13_helm")
}
starting_rings = Array[ExtResource("2_equip_script")]([])
starting_consumables = Array[ExtResource("4_cons_script")]([ExtResource("7_potion"), ExtResource("8_bomb")])
starting_blessings = Array[ExtResource("5_bless_script")]([ExtResource("6_blessing")])
```

### Mage-like additions (add to [resource] block if non-default)

```
class_mana_bonus = 10.0
mana_regen_per_turn = 1.0
starting_prep_slots = 3
starting_learned_spells = Array[Resource]([ExtResource("N_spell")])
starting_prepared_spells = Array[Resource]([ExtResource("N_spell")])
```

## Save path

`resources/classes/<snake_case_name>.tres`

After writing, confirm the path and ask if the user wants to continue with another content type.
