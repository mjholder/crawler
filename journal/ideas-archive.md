# Ideas & Backlog — Archive

Ideas that have been **resolved** — either shipped (`completed`) or dropped (`abandoned`).
Moved out of [[ideas.md]] to keep the live backlog lean. Kept here for history: the
original framing, plus a resolution note pointing at where it landed.

Active and partially-done ideas live in [[ideas.md]].

---

## Completed

**Idea:** Authored dungeon floor / event sequencing resource
**Added:** 2026-05-23
**Resolved:** 2026-05-23 — `completed`
**Outcome:** Shipped as the polymorphic slot system — a single `FloorSlot` resource with a `type` enum (FIXED / RANDOM_TYPE / WEIGHTED), arrayed on `DungeonFloorData`, assigned to world-map nodes at run-start via `FloorEventPool`. Replaces the per-directory random globbing. See [[design.md]] "Authored dungeon floors with polymorphic slot system" and [[daily/2026-05-23]].
**Original notes:** Currently `DungeonMapNode` picks events randomly from a directory. The idea is a `DungeonFloor` (or similar) resource that specifies an ordered or weighted list of events instead — letting designers author the shape of a floor: which events appear, in what order or with what weights, and what the boss is. Would need a new Godot resource class, `.tres` wrappers, and a custom editor view in the content editor (likely a simple ordered list, not a graph). Runtime `DungeonMapNode` would load the floor resource instead of globbing a directory. Deferred from content editor v3 scope.

---

**Idea:** External content authoring tool
**Added:** 2026-05-20
**Resolved:** `completed` (v1)
**Outcome:** Built as `tools/content_editor` — Vite/React frontend plus a Node sidecar with a native TS `.tres` parser (no Godot on the hot path). Schema-driven forms plus table views for the content types, where-used index, and round-trip-safe writes. The v1 goal — unblock balance iteration outside Godot's inspector — is met. The dialogue-graph (v2), inline sub-resource creation, enemy authoring, and modding-wrap follow-ons are tracked as their own entries in [[ideas.md]] / this archive.
**Original notes:** A standalone app for authoring game content as concepts rather than files. The motivating pain isn't any one resource being hard to edit — it's that a single conceptual unit (a weapon, a class, a dialogue tree) is spread across multiple .tres and .json files with no view of the relationships and no validation until runtime.
Why now: The game's balance is currently rough and needs real iteration — change a number, playtest, change another. Each iteration cycle is gated by multi-file editing through Godot's inspector, and the friction is high enough that balance work isn't happening. The tool's primary job, framed honestly, is unblocking design iteration on a game that's too barebones to evaluate without faster content authoring.
Long-term vision: If the game ever ships and finds players, this tool is the natural seed of a modding interface — players use the same forms and tables to author their own weapons, classes, dialogue. That vision shapes architecture but not v1 scope. Concretely it means: schema exported from Godot rather than hardcoded, output is plain text in known locations, no assumptions about project layout beyond Godot's. Get those right in v1 and the path to a mod tool is mostly packaging and polish later.
Design direction: concept-oriented not file-oriented; schema source of truth lives in Godot; direct repo writes (no staging); round-trip safe `.tres` text; relational where-used view; spreadsheet-style table views for balance; a linter for what Godot only catches at runtime.
Platform: v1 localhost web app (Vite + React + Node sidecar); v∞ Tauri wrap when modding is a real concern.
Scope phasing: v1 forms + tables for weapons, armor, attacks, effects, classes, shops; v2 dialogue tree graph editor; linter incrementally; modding wrap only once modders are a realistic audience.
Risk noted at the time: tool-building feels like progress and can outlast its usefulness — "done for v1" defined as having iterated on weapon balance for at least one playtest session using the tool.

---

**Idea:** Defense & Dodge Formula
**Added:** 2026-05-15
**Resolved:** 2026-05-19 — `completed`
**Outcome:** Shipped as flat-percentage damage reduction for DEF and flat-percentage dodge chance for AGI (`DEF = 50` → 50% reduction; `AGI = 15` → 15% dodge), no scaling constants. The armor tradeoff-triangle direction (heavy / leather / robes with `spell_cost_multiplier`) is realised through the spell system and equipment data. See [[design.md]] "Flat-percentage defense and dodge formulas" and [[daily/2026-05-19]].
**Original notes:** Flat defense subtraction (the current first pass) breaks at the extremes — high defense nullifies weak enemies entirely. Roguelikes need legible rules the player can reason about, so fancy scaling formulas are out. Settled direction: flat percentage damage reduction for DEF, flat percentage dodge chance for AGI. Both are immediately readable. Base stats should remain relatively flat across a run; power growth comes from gear and boon tiers, not raw stat inflation. Armor tiers map to a tradeoff triangle with no hard equip requirements (class-aligned loot pools handle access): heavy (high DEF%, AGI penalty, high spell cost), leather (moderate DEF%, neutral AGI/cost), robes (low DEF%, low spell cost or SPI bonus). Spell cost multiplier is a float field on EquipmentData applied multiplicatively at cast time. Overpowered builds are acceptable as rare RNG edge cases, not the intended path.

---

**Idea:** Core Player Stats
**Added:** 2026-02-22
**Resolved:** `completed` (foundational)
**Outcome:** The six base stats — STR / CON / AGI / SPI / LCK — plus derived Health and Defense are implemented as `@export` base stats on Player/Enemy, with effective values computed by layering equipment modifiers on top (see [[detailed/character.md]] and `scripts/enums.gd` `Enums.Stat`). Most of the original open questions resolved in practice: stats grow on level-up, DEF/AGI use the flat-percentage formulas (above), and SPI drives the mana pool and spell scaling via the spell system. INT was not added — SPI remains the sole magic stat.
**Original notes:** Seven base stats that drive all character interactions — Health (from CON), Defense (mitigation + AGI dodge + armor), Strength (power melee, heavy-armor/weapon gating), Constitution (max HP, status resistance), Agility (passive dodge, finesse/ranged damage, light-gear gating), Spirit (occult/devotional magic — spell damage, resource pool, effect potency), Luck (crit chance, loot quality, small bonus on checks). Weapon-class gating by stat check (STR heavy, AGI finesse/ranged, SPI catalysts). Damage scales off the matching stat; hybrid weapons TBD. Open questions at the time covered growth-on-level-up, integer vs modifier values, defense stacking, LCK's interaction with checks, whether SPI affects non-damage magic, the mana resource, and a possible later INT path.

---

## Abandoned

**Idea:** Combat Balance — Defense, Dodge, and Armor Tiers
**Added:** 2026-05-07
**Resolved:** `abandoned` — superseded
**Outcome:** This first pass (percentage DEF as `damage * (1 - defense_ratio)`, AGI dodge as `agility * 0.003` capped ~40–50%, armor tradeoff triangle, `spell_cost_multiplier`) was reworked into the 2026-05-15 "Defense & Dodge Formula" idea, which dropped the scaling constants in favour of flat percentages and shipped 2026-05-19 (see Completed, above). Kept for history; do not revive this version.
**Original notes:** Reworking the first-pass flat defense subtraction which nullifies weak enemies entirely and can't be balanced across both ends of the damage scale. Defense moves to percentage-based reduction (`damage * (1 - defense_ratio)`); dodge introduced as a separate AGI-driven evasion layer (`agility * 0.003`, capped ~40–50%, rolled before damage). Armor tiers as a tradeoff triangle, no stat gating (class-aligned pools instead): heavy (high DEF, −AGI, `spell_cost_multiplier` ~1.5), leather (moderate DEF, neutral AGI/cost), robes (little/no DEF, ~0.8 cost or SPI bonus). `spell_cost_multiplier: float = 1.0` new on EquipmentData, applied multiplicatively at cast time. Pure mages start with a mage-armor spell rather than gear. UI: inventory detail panel diffs candidate vs equipped `stat_modifiers` in green/red; active effects panel shows contributing sources.

---

**Idea:** Grid-Based Equipment System
**Added:** 2026-02-22
**Resolved:** `abandoned`
**Outcome:** The equipment system went a different route — discrete named slots and a paper-doll model (`Enums.Slot`, `Equipment` / `EquipmentData`, the `paper_doll/` sprite layers) rather than the Resident Evil / Diablo grid-fit concept described here. Items occupy a slot, not grid cells; there is no spatial fitting. The modifier ideas (stat bumps, set bonuses, sockets) partly live on as `EquipmentData.stat_modifiers` and the Effect-pipeline passives, but the grid framing itself is dropped.
**Original notes:** Players equip gear that occupies grid cells on a character sheet — similar to Resident Evil / Diablo-style inventory but applied to the body. Each equipment slot (torso, legs, head, hands, feet, fingers, wrists, neck) maps to a region of the grid; items have shapes that must fit. Categories: armor (heavy/light/none), clothing (over/under armor), weapons (1H/2H/ranged/off-hand, unlock special moves), shields (off-hand, block/parry, size vs mobility), jewelry (small footprint, high modifier density). Modifier considerations: attack modifiers (damage type, to-hit, crit range, on-hit effects), defense modifiers (per-type reduction, block, dodge, resistances), passive stat changes, encumbrance, set bonuses, socket/condition slots. Grid questions: fixed body-silhouette vs flat grid; overlapping vs strict-exclusion slots; race/body-type differences. Integration points: combat queries equipped weapon(s); defense aggregates armor/shield per type; enemies use the same structure; loot fits the grid schema; dedicated equipment-screen UI.
