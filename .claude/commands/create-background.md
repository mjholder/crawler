---
name: create-background
description: Interactive questionnaire to create a new BackgroundData .tres for the crawler roguelike. Saves to resources/backgrounds/. Backgrounds are the "who you were" character-creation layer — a stat shift, starting gold, economy modifiers, and one optional passive.
model: claude-haiku-4-5-20251001
---

# Create Background

Generate a valid `BackgroundData` `.tres`. Ask each group, then write the file.

A Background is the *who you were* layer of character creation (alongside class and patron saint).
Theme: civilians forced to adventure. Each should answer *what did this person do before, and what
trace did it leave on them?* A small drawback (a negative stat) is encouraged to match the gothic tone.

## Enum reference

```
Stat:  STR=0  DEF=1  CON=2  AGI=3  SPI=4  LCK=5
```

## Known UIDs — embed verbatim, never fabricate or modify

```
background_data.gd  (no UID — path-only reference)   path: res://scripts/background_data.gd
blessing_data.gd    uid://jvfhxoq8sxt2               path: res://scripts/blessing_data.gd
```

Available passive blessings (only if you want a behavioral passive):
`battle_fury, fortitude, iron_skin, vampiric_pact, warriors_resolve, mage_armor`
(or a custom BlessingData under `resources/backgrounds/passives/`).

## Questionnaire

**Group 1 — Identity**
Display name and flavour description (one or two sentences, gothic tone)?

**Group 2 — Stat shift** (signed; small bump, optionally a small drawback)
Format "LCK:8 STR:-4" (omit stats that don't change)? [none]

**Group 3 — Economy**
- starting_gold (flat gold at run start; reference: 0–200)? [0]
- gold_reward_multiplier (1.0 = none; e.g. 1.25 = +25% gold from events)? [1.0]
- shop_buy_multiplier (1.0 = none; <1.0 = cheaper buys, e.g. 0.85)? [1.0]
- shop_sell_multiplier (1.0 = none; >1.0 = better sells, e.g. 1.2)? [1.0]

**Group 4 — Passive (optional)**
One unique passive blessing (name from Available list, a custom one, or none)? [none]

## Output format

Rules:
1. **No uid on `[gd_resource]` header.**
2. **background_data.gd** — ext_resource with path only, NO uid attribute.
3. **passive** — include the blessing ext_resource (with uid when known) and a `passive = ExtResource("...")` line only if a passive was chosen; otherwise omit the line entirely.
4. **stat_modifiers** — plain dict mapping stat int → float; omit entirely if empty. Values may be negative.
5. **Omit fields at their default** — don't emit `gold_reward_multiplier = 1.0`, `shop_buy_multiplier = 1.0`, `shop_sell_multiplier = 1.0`, or `starting_gold = 0`.

### Template (Failed Business Owner — stat shift + economy, no passive)

```
[gd_resource type="Resource" script_class="BackgroundData" format=3]

[ext_resource type="Script" path="res://scripts/background_data.gd" id="1_bgdata"]

[resource]
script = ExtResource("1_bgdata")
display_name = "Failed Business Owner"
description = "FLAVOUR DESCRIPTION"
stat_modifiers = {
0: -4.0,
5: 8.0
}
starting_gold = 150
gold_reward_multiplier = 1.25
shop_buy_multiplier = 0.85
shop_sell_multiplier = 1.2
```

### Passive addition (add to header + [resource] block if a passive was chosen)

```
[ext_resource type="Resource" path="res://resources/blessings/<passive>.tres" id="2_passive"]
...
passive = ExtResource("2_passive")
```

## Save path

`resources/backgrounds/<snake_case_name>.tres`

After writing, confirm the path and ask if the user wants to create another.
