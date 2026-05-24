# Content Editor — User Guide

A single-page reference for every screen and resource type in the editor.
Each section has an anchor so you can deep-link directly to it (e.g. `USER_GUIDE.md#dialogue-editor`).

---

## Table of Contents

**Part 1 — Tools**
1. [Sidebar — Content Browser](#sidebar)
2. [Form View — Generic Resource Editor](#form-view)
3. [Table View](#table-view)
4. [Where-Used Panel](#where-used)
5. [Dialogue Editor](#dialogue-editor)
6. [Event Editor](#event-editor)
   - [Combat / Boss Events](#combat-and-boss-events)
   - [Skill Check Events](#skill-check-events)
   - [Rest Events](#rest-events)
   - [Dialogue Events](#dialogue-events)
7. [Schema Refresh](#schema-refresh)

**Part 2 — Resource Reference**
- [WeaponData](#weapondata)
- [EquipmentData (Armor / Rings)](#equipmentdata)
- [AttackData](#attackdata)
- [Effects: Damage, Heal, Buff, Status](#effects)
- [ConditionalModifier](#conditionalmodifier)
- [ProcDef](#procdef)
- [StatusData](#statusdata)
- [ConsumableData](#consumabledata)
- [PlayerClassData](#playerclassdata)
- [ShopData](#shopdata)
- [BlessingData](#blessingdata)
- [SpellData](#spelldata)
- [TomeData](#tomedata)
- [DialogueData](#dialoguedata)
- [Event wrapper types](#event-wrapper-types)
- [DungeonFloorData](#dungeonfloordata)
- [FloorSlot](#floorslot)
- [WeightedEntry](#weightedentry)

**Part 3 — Common Workflows**
- [Add a new weapon end-to-end](#workflow-add-weapon)
- [Add a dialogue branch to an existing event](#workflow-add-dialogue-branch)
- [Bulk-tune damage across all weapons](#workflow-bulk-tune)
- [Track down what references an effect](#workflow-where-used)

---

## Part 1 — Tools

---

### Sidebar

The sidebar lists every content category. Clicking a category loads the list
of all `.tres` files of that type in the main panel. Clicking a file name opens
it for editing.

**Creating a new resource** — click the `+` button to the right of any
category name. The editor prompts for a filename (no extension needed). The
file is immediately created and opened.

**Effects subclass picker** — the Effects row uses `DamageEffect` as the
default new-file class. When you click `+`, a small prompt asks which concrete
type to create: `DamageEffect`, `HealEffect`, `BuffEffect`, or `StatusEffect`.
Pick the right one before confirming — the class baked into the `.tres` cannot
be changed after creation without deleting and recreating the file.

**Custom-view categories** — Dialogues and all five event types (Combat, Boss,
Dialogue, Skill Check, Rest) open a specialized editor instead of the generic
Form / Table. The Form / Table toggle is hidden for these.

---

### Form View

The form view is the main way to edit any `.tres` resource. Select a file from
the sidebar to open it.

**Header strip** — shows the Godot class name, the `res://` path, and the UID.
These are read-only metadata.

**Property list** — every `@export` field from the GDScript class is rendered
as a row: label on the left, widget on the right. Parent class fields appear
first (e.g. a `WeaponData` form shows `EquipmentData` fields before
`WeaponData`-specific ones).

**Field widgets by type:**

| Widget | When it appears |
|---|---|
| Checkbox | `bool` fields |
| Number input | `int` or `float` fields |
| Text input | `String` fields (single line) |
| Textarea | `String` field named `description` (auto-multiline) |
| Monospace text input | `StringName` fields |
| Dropdown | `enum` fields — shows name + integer value |
| Stat-dict editor | `Dictionary` keyed by `Enums.Stat` — shows stat-name dropdowns paired with number inputs; use `+ Add stat` to add a row |
| Array editor | `Array[Resource]` or `Array[StringName]` — indexed rows with `×` to remove, `+ Add` at the bottom; if the element type has subclasses a prompt asks which one |
| Resource picker (dropdown) | `Resource` field pointing to a `.tres` — lists all files of the matching class; `→` navigates into the selected file |
| Asset picker (dropdown) | `Resource` field pointing to `Texture2D`, `AudioStream`, `SpriteFrames`, or `PackedScene` — lists files under `assets/` or `scenes/` |
| `inline` button | Appears on resource pickers — embeds the resource directly into this file instead of linking it externally; shows `[inline: ClassName]` with a `link instead` button to revert |
| Raw JSON textarea | Any other type — fallback for complex fields not covered above |

**Navigating into sub-resources** — clicking `→` next to a resource ref pushes
the referenced file onto a navigation stack and opens it in the same panel.
A `← Back` button appears in the toolbar to return to the parent.

**Saving** — click Save. The editor runs the linter first and shows any
warnings inline (dangling references, invalid expression variables). Warnings
do not block the save; they are advisory.

---

### Table View

The table view shows every resource of a class as rows in a spreadsheet.
Switch to it via the **Table** button in the toolbar (only available for
non-custom-view categories).

**When to use it** — bulk tuning. If you want to compare and edit `price` or
`stat_modifiers` across all weapons at once, the table is faster than opening
each form individually.

**Inline-editable cells** — `bool`, `int`, `float`, `String`, and `enum` fields
are editable in place: click the cell, change the value.

**Summary cells** — complex fields (arrays, resource refs, stat dicts) show a
short summary string. Click the cell to open that specific resource in the form
view.

**Saving** — a single **Save All** button at the top writes every row that has
an unsaved change.

---

### Where-Used

The Where-used panel appears at the bottom of the form view whenever the
open resource has a UID. It lists every other `.tres` file in the project that
holds a reference to this resource.

Each entry is a clickable link — clicking it navigates to that file using the
same nav stack as the `→` button.

**Example:** open `chop_damage.tres`, read its effects, then scroll down to
Where-used to see every `AttackData` that includes it. From there navigate to
each attack to audit the full chain.

The index is updated automatically on every save; the list is always current.

---

### Dialogue Editor

Dialogues use a **twin-file** pattern: a thin `.tres` shell (`DialogueData`)
holds the display name and layout positions; the actual content lives in a
sibling `.json` file. When you open a `DialogueData` for the first time (before
a `.json` exists), the editor auto-creates the sibling JSON and writes its path
back into the `.tres`.

**Graph** — nodes are cards on a React Flow canvas. Drag to reposition; scroll
to zoom. Click a node to select it and open its editor panel on the right.

**Node panel fields:**

| Field | What it controls |
|---|---|
| Speaker | Who is speaking. Leave blank for narrator/ambient text. |
| Text | The dialogue line shown to the player. |
| Consequence | Optional one-off side effect when this node is reached. See below. |
| Rewards | XP and gold granted when the player reaches this node. Leave 0 for no reward. |
| Choices | The options presented to the player. A node with zero choices is a **terminal node** — the dialogue ends there. |

**Choices** — each choice has a label (shown to the player) and a target node
set by drawing an edge in the graph. Add a choice with `+ Add`, then drag from
the orange handle on the choice row to the target node. Each choice handle
allows only one outgoing edge; drawing a new one replaces the old.

**Consequences** — when the player reaches a node, a single consequence fires
before the dialogue moves on:

| Action | `value` field | In-game effect |
|---|---|---|
| `give_item` | `res://` path to an `EquipmentData` | Adds the item to the player's bag |
| `give_gold` | Integer string, e.g. `"50"` | Gives the player that many gold |
| `set_flag` | Any string key, e.g. `"met_merchant"` | Sets a boolean flag; useful for branching in scripted events |
| `trigger_event` | Event identifier (not yet wired to game logic) | Placeholder for future scripted triggers |

**Toolbar buttons:**
- `+ Node` — adds a new unconnected node at the bottom of the canvas.
- `Delete "N"` — deletes the selected node; warns if other nodes reference it.
- `Save*` / `Saved` — saves both the JSON and the position data in the `.tres`.

**Layout** — on first open, nodes are auto-positioned using BFS from node `0`.
After that, positions are saved per-node in `node_positions_json` in the `.tres`
and restored on the next open.

**Example — 3-node intro → choice → branch:**

1. Open a new `DialogueData`. The editor auto-creates a JSON with node `0`.
2. Edit node `0`: Speaker `Guard`, Text `"Halt! State your business."`, add two
   choices: `"I'm a traveller"` and `"None of your concern."`.
3. Click `+ Node` twice to create nodes `1` and `2`.
4. Edit node `1`: Text `"Carry on, then."`, no choices (terminal).
5. Edit node `2`: Text `"I'll remember that."`, Consequence `set_flag` / value
   `"rude_to_guard"`, no choices (terminal).
6. Drag from choice-`0`'s orange handle on node `0` to node `1`. Drag from
   choice-`1`'s handle to node `2`.
7. Save.

---

### Event Editor

Events also use the twin-file pattern: a `.tres` wrapper (e.g. `CombatEventData`)
holds the `display_name` and the `event_path` pointing at a sibling `.json`.
The `.json` is auto-created on first open.

All event types share the same **header bar**: an editable Display Name field
and a Save button. The body below the header varies by event type.

---

#### Combat and Boss Events

Used for: regular combat encounters and boss fights. Both use
`CombatEventForm`. A `BossEventData` gets the same form with two extra features:
per-wave `on_clear_trigger` and a dedicated Dialogue Triggers section.

**Waves** — a combat event is a sequence of waves. Each wave runs until all
enemies in it are dead, then the next wave begins. Add waves with `+ Add Wave`;
remove with `× Remove`.

Per wave:
| Field | What it controls |
|---|---|
| Enemy rows | Each row: a scene picker (dropdown of `PackedScene` files under `scenes/`) and a count. Multiple rows = multiple enemy *types* in the same wave. |
| `on_clear_trigger` *(boss only)* | Which dialogue trigger fires when this wave is cleared. Options: `on_start`, `on_mid`, `on_victory`. Use `on_mid` to fire a boss taunt partway through the fight. |

**Dialogue Triggers** — boss events (and combat events once they have at least
one wave) show three optional trigger slots:

| Trigger | When it fires |
|---|---|
| `on_start` | When the event begins, before wave 1. |
| `on_mid` | When a wave with `on_clear_trigger = "on_mid"` is cleared. |
| `on_victory` | When all waves are cleared and the fight ends. |

Each trigger is a path picker pointing to a `.json` dialogue file (the sibling
JSON for a `DialogueData`, not the `.tres`). Click `→` to navigate to and edit
the linked dialogue.

**Rewards** — XP and gold given to the player on event completion.

**Example — a two-wave combat encounter:**
- Wave 1: `res://scenes/skeleton.tscn` × 2
- Wave 2: `res://scenes/skeleton.tscn` × 1, `res://scenes/skeleton_lord.tscn` × 1
- Rewards: experience `40`, gold `15`

**Example — a boss fight with mid-combat dialogue:**
- Wave 1: skeleton × 1 — `on_clear_trigger: on_mid`
- Wave 2: skeleton_lord × 1
- Dialogue Triggers: `on_start` → boss intro dialogue, `on_mid` → boss taunt,
  `on_victory` → boss defeat dialogue
- Rewards: experience `150`, gold `75`

---

#### Skill Check Events

A single stat roll against a hidden DC. The player sees a prompt and the
outcome (success / failure) triggers different dialogue and rewards.

| Field | What it controls |
|---|---|
| `name` | Internal identifier used by scripted floor sequences. |
| `label` | The prompt shown to the player in the UI, e.g. `"Sneak past the guard"`. |
| `stat` | Which stat is rolled: STRENGTH, DEFENSE, CONSTITUTION, AGILITY, SPIRIT, LUCK. |
| `on_success dialogue` | Path to a dialogue JSON played on success (optional). |
| `on_failure dialogue` | Path to a dialogue JSON played on failure (optional). |
| `rewards_on_success` | XP and gold granted on success. |
| `rewards_on_failure` | XP and gold granted on failure (can be 0 / empty). |

Note: the DC (difficulty class) is not stored in the JSON — it is resolved by
the event scene at runtime. This field is planned but not yet exposed in the
editor.

**Example:**
```json
{
  "name": "sneak_past_guard",
  "label": "Sneak past the guard",
  "stat": "AGILITY",
  "rewards_on_success": { "experience": 15, "gold": 0 },
  "rewards_on_failure": {},
  "on_success": "",
  "on_failure": ""
}
```

---

#### Rest Events

A rest stop that heals the player by a configurable expression.

| Field | What it controls |
|---|---|
| `heal_expression` | A stat expression evaluated against the player. The result is the flat HP healed. |

Available variables in the expression: `max_health`, `health`, `spirit`,
`constitution`, `strength`, `defense`, `agility`, `luck`.

| Expression | Heals |
|---|---|
| `max_health * 0.5` | 50% of max HP |
| `max_health * 0.25` | 25% of max HP |
| `spirit * 3` | 3 × the player's current Spirit stat |
| `50` | A flat 50 HP |

---

#### Dialogue Events

A pure story beat — no combat, no roll. Just fires a dialogue sequence.

| Field | What it controls |
|---|---|
| `name` | Internal identifier. |
| `dialogue` | Path to a dialogue JSON (the sibling `.json`, not the `.tres`). Click `→` to navigate to it. |

---

### Schema Refresh

The `↻ schema` button is in the top-right of the toolbar whenever a content
type is selected.

Click it when the field list looks stale — for example, you added a new
`@export` to a GDScript, reloaded the project in Godot, and the editor is not
showing the new field. The button re-runs the Godot schema export in the
background, updates the cached `schema.json`, and reloads the UI with the new
field list.

---

## Part 2 — Resource Reference

---

### WeaponData

Extends `EquipmentData`. Stores everything needed to equip a weapon and use
it in combat.

**Fields inherited from EquipmentData** — see [EquipmentData](#equipmentdata).

**WeaponData-specific fields:**

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `attacks` | The list of moves this weapon gives the player. Each entry is an `AttackData`. They are presented as action buttons on the player's turn. | Array of `AttackData` refs | `[slash.tres, cleave.tres, brace.tres]` |
| `innate_spells` | Spells automatically known (and castable) while this weapon is equipped. | Array of `SpellData` refs | `[]` |
| `is_two_handed` | If true, equipping this weapon occupies the off-hand slot as well. | Checkbox | `false` |
| `attack_sfx` | Sound played on attack. | Asset picker (AudioStream) | |

**Example — Battle Axe:**
- `item_name`: `Battle Axe`
- `attacks`: `[slash, cleave, brace]`
- `stat_modifiers`: `STRENGTH +10`
- `price`: `80`
- `proc_effects`: one `ProcDef` — 25% chance on hit to apply Poison

---

### EquipmentData

Base class for all equippable items. `WeaponData`, `ConsumableData`, and armor
pieces all extend this.

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `item_name` | Display name shown in the UI. | Text | `"Plate Helm"` |
| `description` | Flavour/tooltip text. | Textarea | `"Forged iron protection."` |
| `sprite_frames` | Animation frames for the weapon hand or paper-doll layer. | Asset picker (SpriteFrames) | |
| `paper_doll_front` | Texture drawn on top of the character silhouette (front layer). | Asset picker (Texture2D) | |
| `paper_doll_back` | Texture drawn behind the character silhouette (back layer). | Asset picker (Texture2D) | |
| `equip_sfx` | Sound played when the item is equipped. | Asset picker (AudioStream) | |
| `unequip_sfx` | Sound played when the item is unequipped. | Asset picker (AudioStream) | |
| `stat_modifiers` | Flat bonuses to stats while this item is equipped. Keys are `Enums.Stat` integers. | Stat-dict editor | `STRENGTH +10, DEFENSE +5` |
| `scene` | The Equipment or Weapon scene to instantiate in the game tree. | Asset picker (PackedScene) | `res://scenes/weapon.tscn` |
| `slot` | Which equipment slot this item occupies. | Enum dropdown (Enums.Slot) | `WEAPON (0)`, `HEAD (5)`, `OFFHAND (6)` |
| `is_ring` | Set true for rings; they go into the ring slots rather than body slots. | Checkbox | `false` |
| `price` | Base price in the shop. Modified by the shop's `buy_price_multiplier`. | Number | `80` |
| `on_equip_effects` | Effects that fire once when the item is equipped (e.g. a one-time buff on pickup). | Array of `Effect` refs | |
| `on_unequip_effects` | Effects that fire once when the item is removed. | Array of `Effect` refs | |
| `proc_effects` | Conditional procs that fire during combat while this item is equipped. See [ProcDef](#procdef). | Array of `ProcDef` refs or inline | |
| `conditional_modifiers` | Stat bonuses that are only active while a guard condition is true. See [ConditionalModifier](#conditionalmodifier). | Array of `ConditionalModifier` refs or inline | |
| `spell_cost_multiplier` | Multiplier applied to the mana cost of all spells while equipped. `0.8` = 20% cheaper. | Float | `1.0` |
| `bonus_prep_slots` | Extra prepared-spell slots added while this item is equipped. | Integer | `0` |
| `bonus_mana_regen` | Extra mana restored per turn while equipped. | Float | `0.0` |
| `affinity_tags` | StringName tags used by future affinity / synergy systems. | Array of StringName | `[&"fire"]` |

**Slot integer reference:**

| Integer | Slot |
|---|---|
| 0 | WEAPON |
| 1 | HANDS |
| 2 | FEET |
| 3 | LEGS |
| 4 | TORSO |
| 5 | HEAD |
| 6 | OFFHAND |

---

### AttackData

A single move on a weapon's action list. Defines what happens when the player
uses it (via its `effects` list) and how it looks/sounds.

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `attack_name` | Display name on the action button. | Text | `"Slash"` |
| `description` | Tooltip text. | Textarea | `"A sweeping blow."` |
| `target_mode` | Who the attack hits. | Enum dropdown | `SINGLE_ENEMY (0)`, `ALL_ENEMIES (1)`, `SELF (2)` |
| `effects` | Ordered list of effects that are applied when this attack lands. | Array of `Effect` refs | `[chop_damage.tres]` |
| `icon` | Icon shown on the action button. | Asset picker (Texture2D) | |
| `sound` | Sound played on use. | Asset picker (AudioStream) | |

**Example — Slash:**
- `attack_name`: `"Slash"`
- `target_mode`: `SINGLE_ENEMY`
- `effects`: `[slash_damage.tres]`

**Example — Cleave:**
- `attack_name`: `"Cleave"`
- `target_mode`: `ALL_ENEMIES`
- `effects`: `[chop_damage.tres]`

---

### Effects

Effects are the atomic units of game mechanics. Four concrete types exist;
all are created via the **Effects** sidebar row.

#### DamageEffect

Deals damage to the target equal to the result of `damage_expression`.

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `damage_expression` | Expression evaluated against the **source** (attacker) stats. | Text | `"strength * 0.5"`, `"20 + (strength / 2)"`, `"15"` |

Available variables: `strength`, `defense`, `constitution`, `agility`,
`spirit`, `luck`, `max_health`, `health`.

| Expression | Damage dealt |
|---|---|
| `"strength * 0.5"` | Half the attacker's Strength |
| `"20 + (strength / 2)"` | 20 flat + half Strength |
| `"15"` | Always 15 |
| `"strength + agility * 0.3"` | STR + 30% AGI |

#### HealEffect

Restores HP to the target equal to the result of `heal_expression`.

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `heal_expression` | Expression evaluated against the **target** (the character being healed) stats. | Text | `"max_health * 0.25"`, `"spirit * 3 + 10"`, `"50"` |

#### BuffEffect

Applies a temporary stat buff to the target for a set number of turns.
Internally creates a `StatusData` on the fly; no separate `StatusData` resource
is needed.

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `stat` | Which stat is buffed. | Enum dropdown (Enums.Stat) | `STRENGTH (0)`, `DEFENSE (1)` |
| `amount_expression` | Flat amount added to the stat. Evaluated against the target. | Text | `"20"`, `"spirit * 0.5"` |
| `duration` | Number of turns the buff lasts. | Integer | `3` |

The buff stacks with the REFRESH policy: applying the same buff again resets
the duration.

#### StatusEffect

Applies a pre-authored `StatusData` resource to the target.
Use this when you need a status more complex than a simple stat buff (e.g.
Poison, Stun, Bleed).

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `status_data` | The `StatusData` resource to apply. | Resource picker or inline | `res://resources/effects/statuses/poison.tres` |

---

### ConditionalModifier

A stat bonus that is only active when a runtime condition is true.
Embedded in an `EquipmentData.conditional_modifiers` array.

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `stat` | Which stat is modified. | Enum dropdown (Enums.Stat) | `STRENGTH (0)` |
| `amount_expression` | How much to add. Evaluated against the item holder. | Text | `"10"`, `"constitution * 0.2"` |
| `guard_expression` | Condition check. If this expression evaluates to > 0, the modifier is active. | Text | `"1"` (always on), `"health < max_health * 0.5"` (below half HP) |

**Example — "Berserker" bonus: +20 STR when below 50% HP:**
- `stat`: `STRENGTH`
- `amount_expression`: `"20"`
- `guard_expression`: `"health < max_health * 0.5"`

---

### ProcDef

A conditional effect that may fire automatically during combat.
Embedded in an `EquipmentData.proc_effects` array.

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `trigger` | The game signal that activates this proc. | StringName (monospace text) | `&"player_attack_hit"` |
| `chance_expression` | Probability of firing (0.0–1.0). Evaluated against the proc owner. | Text | `"0.25"` (25%), `"luck * 0.01"` |
| `apply_to_owner` | If true, the effect targets the item's owner instead of the triggering target. | Checkbox | `false` |
| `effect` | The Effect to apply when the proc fires. | Resource picker or inline | `res://resources/effects/apply_poison.tres` |

**Example — 25% chance to Poison on hit:**
- `trigger`: `&"player_attack_hit"`
- `chance_expression`: `"0.25"`
- `apply_to_owner`: false
- `effect`: `apply_poison.tres`

---

### StatusData

Defines a persistent status condition (buff, debuff, DoT) that can be applied
to a combatant.

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `tag` | Unique identifier used for stack/refresh logic. Must be a StringName. | StringName | `&"poison"`, `&"stun"` |
| `display_name` | Label shown in the UI. | Text | `"Poison"` |
| `icon` | Icon shown in the status bar. | Asset picker (Texture2D) | |
| `duration` | How many turns the status lasts. | Integer | `3` |
| `stat_modifiers` | Flat stat changes active while this status is held. | Stat-dict editor | `DEFENSE -20` |
| `prevents_action` | If true, the combatant cannot act on their turn while this status is active (stun). | Checkbox | `false` |
| `on_apply` | Effect that fires once when this status is first applied. | Resource (inline or ref) | |
| `on_tick` | Effect that fires at the start of each of the holder's turns while active (e.g. poison damage). | Resource (inline or ref) | `[inline DamageEffect: "3"]` |
| `on_expire` | Effect that fires once when the status runs out. | Resource (inline or ref) | |
| `stack_policy` | What happens when the same tag is applied again. | Enum dropdown | `REFRESH (0)` — resets timer; `STACK (1)` — adds a new instance; `MAX_DURATION (2)` — extends to the maximum of current and new duration |

**Example — Poison (3 damage per turn, 3 turns, refreshes):**
- `tag`: `&"poison"`, `display_name`: `"Poison"`, `duration`: `3`
- `on_tick`: inline `DamageEffect` with `damage_expression: "3"`
- `stack_policy`: `REFRESH`

---

### ConsumableData

Extends `EquipmentData`. A single-use item placed in the consumable belt.

All `EquipmentData` fields apply. Additional fields:

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `target_mode` | Who the item affects when used. | Enum dropdown | `SELF (0)`, `ALL_ENEMIES (1)` |
| `effects` | Effects applied on use, in order. | Array of `Effect` refs or inline | `[heal_25_flat.tres]` |
| `use_sfx` | Sound played on use. | Asset picker (AudioStream) | |

Note: `slot` on a consumable is ignored — consumables go into belt slots, not
equipment slots. `price` is still used by shops.

---

### PlayerClassData

Defines a playable class: its starting stats, starting equipment, and
per-level growth.

**Starting stats** (all `float`, default 50.0 each):

| Field | Stat it sets | Effect on the player |
|---|---|---|
| `strength` | STR | Scales physical damage expressions |
| `defense` | DEF | Scales damage-reduction expressions |
| `constitution` | CON | Scales max HP (`max_health = CON * modifier + class_health_bonus`) |
| `agility` | AGI | Scales dodge, speed, and AGI-gated checks |
| `spirit` | SPI | Scales max mana and SPI-based spell power |
| `luck` | LCK | Scales proc chances and LCK-gated outcomes |

**Health / mana tuning:**

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `class_health_bonus` | Flat HP added on top of CON-derived max HP. | Float | `20.0` |
| `class_mana_bonus` | Flat mana added on top of SPI-derived max mana. | Float | `0.0` |
| `mana_regen_per_turn` | Mana restored at the start of each player turn. | Float | `1.0` |
| `mana_on_kill` | Mana restored each time the player kills an enemy. | Float | `0.0` |

**Growth (per level-up):**

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `growth_rates` | Dictionary of `Enums.Stat → float` bonuses applied each level. | Stat-dict editor | `STRENGTH +3, CONSTITUTION +2` |

Warrior example: `{ 0: 3.0, 2: 2.0 }` means +3 STR and +2 CON per level.

**Starting equipment** — all of these auto-equip or populate the inventory when
a run begins with this class:

| Field | In-game meaning | Widget |
|---|---|---|
| `starting_equipped` | Slot → `EquipmentData`. One item per body slot at run start. | Stat-dict-style editor (slot keys) |
| `starting_rings` | Rings auto-equipped at run start. | Array of `EquipmentData` refs |
| `starting_bag` | Items placed in the bag (inventory) at run start. | Array of `EquipmentData` refs |
| `starting_consumable_slots` | Number of belt slots the class begins with. | Integer |
| `starting_consumables` | Consumables auto-loaded into belt slots. | Array of `ConsumableData` refs |
| `starting_blessings` | Blessings granted immediately at run start. | Array of `BlessingData` refs |

**Spells:**

| Field | In-game meaning | Widget |
|---|---|---|
| `starting_prep_slots` | How many prepared-spell slots the class starts with. | Integer |
| `starting_learned_spells` | Full spell roster known at run start. | Array of `SpellData` refs |
| `starting_prepared_spells` | Which of the learned spells are prepared (active) at run start. Must be a subset of `starting_learned_spells`. | Array of `SpellData` refs |
| `starting_tomes` | Tomes placed in inventory at run start. | Array of `TomeData` refs |

---

### ShopData

Defines the inventory and pricing of a shop encounter.

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `shop_name` | Display name shown in the shop UI. | Text | `"Pete's Wares"` |
| `stock` | The items for sale. Any `EquipmentData` (weapon, armor, ring, consumable). | Array of `EquipmentData` refs | |
| `buy_price_multiplier` | Multiplier applied to each item's `price` when the player buys. `1.0` = full price. | Float | `1.0` |
| `sell_price_multiplier` | Fraction of `price` the player receives when selling. | Float | `0.5` |

---

### BlessingData

A run-persistent passive bonus. Blessings are granted by class kits or events
and remain active for the entire run.

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `display_name` | Name shown in the blessings list. | Text | `"Warrior's Resolve"` |
| `description` | Tooltip text. | Textarea | `"Increases toughness under duress."` |
| `icon` | Icon shown in the UI. | Asset picker (Texture2D) | |
| `stat_modifiers` | Flat stat bonuses active for the whole run. | Stat-dict editor | `DEFENSE +10` |
| `subscriptions` | Signal → Effect bindings. Each entry fires `effect.apply(player, player)` when the named game signal fires. Use this for reactive procs (on-kill regen, on-hit counter, etc.). Always self-targeted. | Raw JSON fallback | `{ "enemy_died": <HealEffect> }` |

Note: `subscriptions` currently uses the raw JSON widget because it is a mixed-
type Dictionary. Edit it carefully; the key is a signal name string and the
value is an inline Effect object in the Godot JSON marker format.

---

### SpellData

A castable spell. Spells are learned from tomes and prepared into active slots.

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `spell_name` | Display name on the spell button. | Text | `"Magic Missile"` |
| `description` | Tooltip text. | Textarea | `"A bolt of arcane force."` |
| `mana_cost` | Mana consumed on cast. | Float | `5.0` |
| `target_mode` | Who the spell hits. Same options as `AttackData.TargetMode`. | Enum dropdown | `SINGLE_ENEMY (0)`, `ALL_ENEMIES (1)`, `SELF (2)` |
| `effects` | Effects applied on cast, in order. | Array of `Effect` refs or inline | `[damage_spi_half.tres]` |
| `icon` | Icon on the spell button. | Asset picker (Texture2D) | |
| `cast_sfx` | Sound played on cast. | Asset picker (AudioStream) | |

---

### TomeData

A collectible item that teaches a spell. Found in shops and as loot.

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `item_name` | Display name. | Text | `"Tome of Magic Missile"` |
| `description` | Tooltip text. | Textarea | |
| `icon` | Item icon. | Asset picker (Texture2D) | |
| `gold_value` | Sell price. | Integer | `30` |
| `spell` | The spell this tome teaches when read. | Resource picker (`SpellData`) | `magic_missile.tres` |

---

### DialogueData

The `.tres` shell for a dialogue graph. All content lives in the sibling `.json`;
this resource just ties the name and JSON path together.

| Field | In-game meaning | Widget | Notes |
|---|---|---|---|
| `display_name` | Name shown in the dialogue editor toolbar and in pickers. | Text | Set this; it becomes the dialogue's JSON `name` field on save. |
| `dialogue_path` | Path to the sibling `.json` file. | Text (read-only in the dialogue editor) | Auto-set on first open. |
| `node_positions_json` | JSON blob storing `{ nodeId: { x, y } }` positions for the graph. | (managed by the editor) | Do not edit by hand. |

Open a `DialogueData` to get the [Dialogue Editor](#dialogue-editor).

---

### Event Wrapper Types

`CombatEventData`, `BossEventData`, `DialogueEventData`, `SkillCheckEventData`,
and `RestEventData` are all thin wrappers with the same two fields:

| Field | In-game meaning | Widget |
|---|---|---|
| `display_name` | Name shown in the dungeon floor and event pickers. | Text |
| `event_path` | Path to the sibling `.json` file. | Text (auto-set) |

Open any of these to get the [Event Editor](#event-editor) for that type.

---

### DungeonFloorData

Describes one procedural floor template. The dungeon builds a floor by
resolving each `FloorSlot` in the `slots` array in order.

| Field | In-game meaning | Widget | Example |
|---|---|---|---|
| `display_name` | Name shown in logs and the dungeon selector. | Text | `"Standard Medium"` |
| `tags` | String tags used to filter which floors are eligible at a given point in the run (e.g. `["act1"]`, `["boss"]`). | Array of String | `["demo"]` |
| `slots` | Ordered list of `FloorSlot` resources. Each slot produces one event. | Array (inline FloorSlot) | |

---

### FloorSlot

One event position in a `DungeonFloorData`. Resolves to a specific event at
runtime using one of three modes.

| Field | In-game meaning | Widget | Notes |
|---|---|---|---|
| `type` | How this slot selects its event. | Enum dropdown | `FIXED (0)`, `RANDOM_TYPE (1)`, `WEIGHTED (2)` |
| `event` | *(FIXED only)* The specific event wrapper to use. | Resource picker | `combat/example.tres` |
| `event_type` | *(RANDOM_TYPE only)* Pick a random event of this type from all events in `resources/events/<type>/`. | Enum dropdown | `combat (0)`, `boss (1)`, `dialogue (2)`, `skill_check (3)`, `rest (4)` |
| `entries` | *(WEIGHTED only)* Array of `WeightedEntry` objects. One is chosen by weighted random. | Array (inline WeightedEntry) | |

**Examples:**
- Fixed combat: `type = FIXED`, `event = combat/example.tres`
- Any random rest: `type = RANDOM_TYPE`, `event_type = rest (4)`
- Weighted: `type = WEIGHTED`, entries = `[combat × 3, dialogue × 1, rest × 2]`

---

### WeightedEntry

One option in a `FloorSlot` of type WEIGHTED.

| Field | In-game meaning | Widget | Notes |
|---|---|---|---|
| `event` | A specific event wrapper. If set, this entry always resolves to this event. | Resource picker | Leave null to use `event_type` instead. |
| `event_type` | Pick a random event of this type. Only used when `event` is null. | Enum dropdown | Same options as `FloorSlot.event_type`. |
| `weight` | Relative probability. A weight of 3 is 3× as likely as weight 1. Minimum effective weight is 1. | Integer | `3` |

---

## Part 3 — Common Workflows

---

### Add a new weapon end-to-end {#workflow-add-weapon}

1. **Create the AttackData(s).** In the sidebar, click `+` on **Attacks**. Name
   it (e.g. `heavy_swing`). Set `attack_name`, `target_mode`, and add a
   `DamageEffect` to `effects` (ref an existing one or click `inline` to
   embed a new one with the expression you need). Save.

2. **Create the WeaponData.** Click `+` on **Weapons**. Name it (e.g.
   `war_hammer`). Fill in:
   - `item_name` and `description`
   - `attacks` — add the attack(s) you just created
   - `stat_modifiers` — add any stat bonuses
   - `slot` — should be `WEAPON (0)`
   - `scene` — pick `res://scenes/weapon.tscn`
   - `price`
   - `sprite_frames`, `paper_doll_front` — pick the sprite assets
   - Save.

3. **Verify.** Open the Where-used panel — the weapon should have no inbound
   refs yet. Navigate into one of your attacks via the `→` button to confirm
   the damage expression looks right. Navigate back with `← Back`.

4. **Add to a class or shop.** Open a `PlayerClassData` and add the weapon to
   `starting_bag` or `starting_equipped`. Or open a `ShopData` and add it to
   `stock`.

---

### Add a dialogue branch to an existing event {#workflow-add-dialogue-branch}

1. Open the **Dialogue Events** sidebar row and pick (or create) a
   `DialogueEventData`. The Event Editor opens.

2. The `dialogue` field in the form shows which `DialogueData` JSON is linked.
   Click `→` to navigate to it — this opens the Dialogue Editor.

3. In the graph, select the node where you want to add a branch. In the side
   panel, click `+ Add` under Choices, type the choice label.

4. Click `+ Node` to create a new destination node. Edit its text and
   (optionally) a consequence.

5. Draw the edge: drag from the new choice's orange handle to the new node.

6. Save. Navigate `← Back` to the event if needed.

---

### Bulk-tune damage across all weapons {#workflow-bulk-tune}

1. In the sidebar, click **Attacks**.
2. Switch to **Table** view using the toolbar button.
3. Each row is one `AttackData`. The `effects` column shows a summary.
   For rows whose damage you want to change, click the cell to open that
   attack's form view.
4. In the form, navigate into the `DamageEffect` via `→`, edit
   `damage_expression`, save, then `← Back` to the attack.
5. When you've edited all the attacks you care about, return to the table
   and click **Save All** to flush any uncommitted numeric edits.

Alternatively: if you share one `DamageEffect` `.tres` across multiple attacks
(by referencing the same file), editing it once updates all attacks that use it.
Check the Where-used panel on the effect file first to see the blast radius.

---

### Track down what references an effect {#workflow-where-used}

1. In the sidebar, click **Effects** and pick the effect file (e.g.
   `chop_damage.tres`).
2. Scroll to the bottom of the form view — the **Where-used** panel lists every
   `.tres` that holds a reference to this UID.
3. Click any entry to navigate to it and see the full context.

This is useful before changing a `DamageEffect`'s expression: see exactly which
attacks (and therefore which weapons) will be affected, and verify no unintended
hits.
