# Crawler content authoring (MCP)

You are authoring game content for a turn-based roguelike (Godot 4.6). Content is
stored as Godot `.tres` resources and a few JSON files. These tools read and write
those files directly through a native parser — **Godot does not need to be running.**

## Workflow (do this in order)

1. `get_schema(class)` — see the class's fields, types, enums, and which resource
   type each reference field expects.
2. `list_resources(class)` — see what already exists; **reuse** existing leaf
   resources (effects, attacks, statuses) by reference instead of duplicating them.
3. `read_resource(<an existing sibling of the same class>)` — this is your most
   reliable guide to the **exact envelope shape**. Copy its structure.
4. **Bottom-up:** create leaf resources first (effects, attacks, blessing tiers,
   status data), capture their `res://` paths, then `write_resource` the parent
   referencing them by `{ "__ref": "res://..." }`.
5. Check the `lint` array returned by `write_resource`. Empty = good. Non-empty =
   fix dangling refs / bad expression variables and write again.

## The JSON envelope

`write_resource(path, class, fields)` — you supply `fields` (everything except
`_godot_meta`, which the tool assembles from `class`). Field values follow these
encodings (seen in any `read_resource` output):

- **Scalars** — plain JSON: `"mana_cost": 5`, `"display_name": "Fireball"`.
- **Enum values** — integers. `"target_mode": 0`, `"slot": 0`.
- **External resource reference** — `{ "__ref": "res://path/to/file.tres" }`.
  (A `__uid` may also appear when read back; you only need `__ref` when writing.)
- **StringName** — `{ "__sn": "player_attack_hit" }` (used for signal/tag fields).
- **Dictionary** — a JSON object plus a `__key_type` marker, e.g. stat modifiers:
  `"stat_modifiers": { "0": 10, "5": -4, "__key_type": "int" }`.
- **Typed array** — a JSON array of values: `"effects": [ { "__ref": "..." } ]`.
- **Inline sub-resource** — a nested object with its own `_godot_meta`
  (`"inline": true`) when a child resource is owned by this file rather than
  shared. Prefer a standalone `__ref` for anything reusable.

### Real examples

Spell referencing a shared effect:
```json
{ "spell_name": "Magic Missile", "description": "A bolt of arcane force.",
  "mana_cost": 5, "target_mode": 0,
  "effects": [ { "__ref": "res://resources/effects/damage_spi_half.tres" } ] }
```

Weapon with a stat modifier dict and an inline proc:
```json
{ "item_name": "Battle Axe", "description": "One Handed axe", "price": 80,
  "attacks": [ { "__ref": "res://resources/attacks/slash.tres" } ],
  "stat_modifiers": { "0": 10, "__key_type": "int" },
  "proc_effects": [ {
    "_godot_meta": { "class": "ProcDef", "script": "res://scripts/proc_def.gd", "inline": true },
    "trigger": { "__sn": "player_attack_hit" },
    "chance_expression": "0.25",
    "effect": { "__ref": "res://resources/effects/apply_poison.tres" } } ] }
```

A status is applied via a `StatusEffect` wrapper — **never** put a bare `StatusData`
in an `effects` array:
```json
{ "status_data": { "__ref": "res://resources/effects/statuses/poison.tres" } }
```

## Where each class lives (`snake_case` filenames)

| Class | Directory |
|---|---|
| `WeaponData` | `res://resources/equipment/weapons/` (mage variants → `mage/`) |
| `EquipmentData` (armor) | `res://resources/equipment/armor/<plate\|leather\|mage>/` |
| `EquipmentData` (ring, `is_ring=true`, no `slot`) | `res://resources/equipment/rings/` |
| `ConsumableData` | `res://resources/equipment/consumables/` |
| `PlayerClassData` | `res://resources/classes/` |
| `BackgroundData` | `res://resources/backgrounds/` (passive blessings → `passives/`) |
| `PatronSaintData` | `res://resources/patron_saints/` |
| `BlessingData` (saint tier) | `res://resources/patron_saints/tiers/` (named `<lineage>_tier1.tres` …) |
| `BlessingData` (reusable) | `res://resources/blessings/` |
| `SpellData` | `res://resources/spells/` |
| `TomeData` | `res://resources/tomes/` |
| `AttackData` | `res://resources/attacks/` |
| effects (`DamageEffect`/`HealEffect`/`BuffEffect`/`StatusEffect`) | `res://resources/effects/` (`buffs/`, `statuses/`) |
| `StatusData` | `res://resources/effects/statuses/` |
| `ShopData` | `res://resources/shops/` |
| `DungeonFloorData` | `res://resources/dungeon_floors/` |
| event JSON (`read_event`/`write_event`) | `res://resources/events/<combat\|dialogue\|boss\|skill_check\|rest>/` |
| dialogue JSON (`read_dialogue`/`write_dialogue`) | `res://resources/dialogue/` |

## Enums (write the integer)

- **Stat** — STR=0, DEF=1, CON=2, AGI=3, SPI=4, LCK=5.
- **Slot** — WEAPON=0, HANDS=1, FEET=2, LEGS=3, TORSO=4, HEAD=5, OFFHAND=6.
- **TargetMode** — SINGLE_ENEMY=0, ALL_ENEMIES=1, SELF=2.

Always confirm against `get_schema(class)`, which reports the live enum tables.

## References must point at real files

- For sprite/audio/scene fields, call `list_assets(Texture2D | AudioStream | PackedScene | SpriteFrames)`
  and reference a path that exists — don't invent asset paths.
- For resource fields, reference an existing `res://...tres` (or one you just wrote).
  Verify the target exists with `list_resources` / `read_resource` **before**
  referencing it — the linter does not catch a `__ref` pointing at a path that was
  never created.
- `lint_resource` / the `lint` from `write_resource` flag dangling `uid://`
  references and unknown variables in expression fields (`damage_expression`,
  `heal_expression`, `amount_expression`, `chance_expression`, `guard_expression`).
  Allowed expression variables: `strength`, `defense`, `constitution`, `agility`,
  `spirit`, `luck`, `max_health`, `health`, plus the weapon-anatomy context vars
  `power`, `scaling`, `scale`, `coeff` (weapon attacks only), plus standard math builtins.

## Weapon damage expressions — use the uniform form, tweak the variables

A weapon basic attack's `damage_expression` is **not** authored as a raw stat formula.
Weapon damage lives on the `WeaponData` (`power`, `scaling`, `scaling_stat`); the attack
effect only carries the shape. The default and expected form is:

```
"power * coeff + scale * scaling"
```

- `power` / `scaling` come from the weapon (composed with smithing / rarity at runtime).
- `scale` is the bearer's effective value of the weapon's declared `scaling_stat`.
- `coeff` is the per-attack shape knob — `AttackData.power_coefficient`, **default `1.0`**.

So to make one attack hit harder than another on the same weapon, **don't rewrite the
expression** — leave it as the uniform form and set `power_coefficient` on the `AttackData`
(1.0 = flat power as-is; 1.3 = +30% of flat power). `coeff` is also a live buff lever:
`AttackCoeffBuffEffect` (`mode` ADD/MULTIPLY) grants a decaying status that shifts it.

Only genuinely non-weapon damage uses raw stat expressions: spells (flat authored damage,
no stat term), self-costs, and status `on_tick`/`on_apply`/`on_expire` bursts (flat).

## Events & dialogue (JSON, not `.tres`)

Dialogue trees use hierarchical node IDs: `"0"` (root), `"0-0"`/`"0-1"` (children),
`"0-1-0"`, … Each node has `speaker` (string or null for narration), `text`,
`consequence` (null or `{ "action": "set_flag", "value": "flag_name" }`), `choices`,
and optional `rewards`. Read an existing event/dialogue file before writing a new one.
