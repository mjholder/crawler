---
name: create-saint
description: Interactive questionnaire to create a new PatronSaintData .tres (plus its three tier BlessingData) for the crawler roguelike. Saves the saint to resources/patron_saints/ and tiers to resources/patron_saints/tiers/. Patron saints are the "what watches over you" character-creation layer — a divine boon that evolves across the run's three acts.
model: claude-haiku-4-5-20251001
---

# Create Patron Saint

Generate a valid `PatronSaintData` `.tres` **and its three tier `BlessingData` files**. Ask each
group, then write all four files.

A Patron Saint is the *what watches over you* layer of character creation. Each saint is a lineage of
three tiers (one per act). Tier 1 is granted at character creation; tiers 2 and 3 arrive via shrine
ascension (Phase 2). Triggers should be *conditional and dramatic*, not flat passives, and **the tithe
scales with tier** — late tiers are dangerous pacts (bigger boons, steeper costs, expressed as larger
negative stat_modifiers). All three tiers share one `lineage_id`.

## Enum reference

```
Stat:  STR=0  DEF=1  CON=2  AGI=3  SPI=4  LCK=5
```

## Known UIDs — embed verbatim, never fabricate or modify

```
patron_saint_data.gd  (no UID — path-only reference)   path: res://scripts/patron_saint_data.gd
blessing_data.gd      uid://jvfhxoq8sxt2               path: res://scripts/blessing_data.gd
```

Subscriptions (signal → Effect) reuse the lifecycle bus, like ordinary blessings. Common signals:
`enemy_died`, `player_attack_hit`, `combat_wave_started`, `player_turn_started`. Reusable effects
include `res://resources/effects/heal_15_flat.tres`. Note: the "first attack deals Nx damage" style
trigger needs a custom effect type that does not exist yet — model such tiers with `stat_modifiers`
(and describe the intended trigger in the description) until that effect lands.

## Questionnaire

**Group 1 — Saint identity**
Display name (e.g. "Saint of Ambush") and a `lineage_id` (snake/lower, e.g. `ambush`)?
One-sentence flavour description of what the saint embodies?

**Group 2 — Tier 1 (Act 1, granted at creation)**
- Tier display name (e.g. "Saint of Ambush — Initiate")?
- Stat shift — format "STR:12 AGI:6" (signed)? 
- Description (the boon, in flavour)?
- Optional subscription (signal:effect, or none)? [none]

**Group 3 — Tier 2 (Act 2)**
Same fields. Broaden the boon AND add a tithe (a negative stat_modifier).

**Group 4 — Tier 3 (Act 3)**
Same fields. Strongest boon, steepest tithe. A subscription (e.g. heal-on-kill) fits here.

## Output format

Write FOUR files. Tier files first (so the saint can reference them), then the saint.

Rules:
1. **No uid on any `[gd_resource]` header.**
2. **blessing_data.gd** ext_resource includes `uid="uid://jvfhxoq8sxt2"`.
3. **patron_saint_data.gd** ext_resource is path-only (no uid).
4. Each tier sets `lineage_id = &"<lineage_id>"` — the SAME value on all three and on the saint.
5. **stat_modifiers** — plain dict, stat int → float; omit if empty. Tithes are negative entries.
6. **subscriptions** — `{&"signal_name": ExtResource("effect_id")}`; include the effect ext_resource and omit the line if no subscription.
7. **tiers** typed array on the saint: `Array[ExtResource("blessing_script_id")]([ExtResource("t1"), ExtResource("t2"), ExtResource("t3")])` — the type arg is the blessing_data.gd script ext_resource id.

### Tier template (tier 3 — stats + tithe + heal-on-kill subscription)

```
[gd_resource type="Resource" script_class="BlessingData" format=3]

[ext_resource type="Script" uid="uid://jvfhxoq8sxt2" path="res://scripts/blessing_data.gd" id="1_bdata"]
[ext_resource type="Resource" path="res://resources/effects/heal_15_flat.tres" id="2_heal15"]

[resource]
script = ExtResource("1_bdata")
display_name = "Saint of Ambush — Avatar"
description = "FLAVOUR — boon and tithe."
stat_modifiers = {
0: 30.0,
1: -12.0,
3: 16.0
}
subscriptions = {
&"enemy_died": ExtResource("2_heal15")
}
lineage_id = &"ambush"
```

### Saint template

```
[gd_resource type="Resource" script_class="PatronSaintData" format=3]

[ext_resource type="Script" path="res://scripts/patron_saint_data.gd" id="1_psdata"]
[ext_resource type="Script" uid="uid://jvfhxoq8sxt2" path="res://scripts/blessing_data.gd" id="2_bdata"]
[ext_resource type="Resource" path="res://resources/patron_saints/tiers/<lineage>_tier1.tres" id="3_t1"]
[ext_resource type="Resource" path="res://resources/patron_saints/tiers/<lineage>_tier2.tres" id="4_t2"]
[ext_resource type="Resource" path="res://resources/patron_saints/tiers/<lineage>_tier3.tres" id="5_t3"]

[resource]
script = ExtResource("1_psdata")
display_name = "Saint of Ambush"
description = "FLAVOUR DESCRIPTION"
lineage_id = &"ambush"
tiers = Array[ExtResource("2_bdata")]([ExtResource("3_t1"), ExtResource("4_t2"), ExtResource("5_t3")])
```

## Save paths

- Saint: `resources/patron_saints/<lineage_id>.tres`
- Tiers: `resources/patron_saints/tiers/<lineage_id>_tier1.tres` (… `_tier2`, `_tier3`)

After writing, confirm the four paths and ask if the user wants to create another.
