# Design Decisions

A log of significant design and architectural decisions, and the reasoning behind them.
Cross-reference daily logs with `See [[design.md]] — [[daily/YYYY-MM-DD]]` when a decision is made.

---

## Template entry

**Decision:** [What was decided]
**Date:** YYYY-MM-DD
**Daily:** [[daily/YYYY-MM-DD]]
**Context:** [What problem or question prompted this]
**Alternatives considered:** [What else was on the table]
**Rationale:** [Why this option]
**Trade-offs / risks:** [What this choice costs or risks]

---

<!-- Add entries below, newest first -->

## Run-state reset pattern

**Date:** 2026-05-08
**Daily:** [[daily/2026-05-08]]

**Decision:** Per-run teardown lives in two explicit reset methods — `Player.reset_run_state()` and `Game._reset_run_state()` — called at the top of every "begin a run" entry point (`_on_character_created`, `_on_continue_requested`). `initialize()` and `apply_save_dict()` both delegate to `reset_run_state()` rather than maintaining their own teardown blocks.

**Context:** After the spell system landed, starting a new run after a death produced zero spells. Root cause: `_on_player_died` → `_exit_event()` sets `_dungeon_locked = true`; `_enter_game_over()` skips `_exit_dungeon()`, so the lock survives through Main Menu into the next `initialize()`, where `_inventory.equip()` silently returns early. Three other latent leaks were co-present: health label showed negative HP on lethal hits; `prep_slots` wasn't reset so `_prepared_spells` stayed size 0 after a clear; `Game.round_number` and stale enemy HUD bars were never cleaned between runs.

**Alternatives considered:**
- `_inventory.set_dungeon_locked(false)` at the top of `initialize()` — fixes the immediate symptom in one line but leaves the other leaks, and leaves duplicate teardown in `initialize` vs `apply_save_dict`.
- Reset on `_enter_game_over()` / `_enter_victory()` — would clear state at the right time but means entering a terminal state has a side-effect of resetting the entity, which is surprising. Better to reset at the *start* of a new run than the *end* of the old one.

**Rationale:** A single-owner contract is easier to audit than teardown scattered across three methods. `reset_run_state()` is also the right seam for future testing — any test that needs a "clean player" calls one method. The refactor *removed* code (duplicate blocks in `initialize` and `apply_save_dict`) rather than adding it.

**Trade-offs / risks:** `reset_run_state()` is now public on `Player`, which means callers outside `initialize` could invoke it mid-run. Acceptable — it's a deliberate API, not an internal detail. No observed risks on the Continue path: `reset_run_state()` unlocks the inventory, then `apply_save_dict` re-equips from save data (which bypasses the lock), then `_on_continue_requested` re-locks when re-entering a dungeon.

---

## Spell casting system — foundation design

**Date:** 2026-05-08
**Daily:** [[daily/2026-05-08]]

**Decision:** Spells are `SpellData` resources (mirrors `AttackData`), registered as player actions and routed through the existing targeting machinery and `execute_action` path. All casts — including cantrips — end the turn. Mana mirrors health: `max_mana = effective_SPI × mana_modifier + class_mana_bonus`, recalculated at every `_recalculate_max_health` call site. `spell_cost_multiplier: float = 1.0` on `EquipmentData` is applied multiplicatively across all equipped pieces at cast time. A new `OFFHAND` slot (value 6, appended to avoid integer drift on existing `.tres` files) is added but no two-handed lock is wired yet.

**Scope for this pass:** mana resource, `SpellData`, OFFHAND slot, prep slots (mirrors consumable belt pattern), innate weapon spells (registered on weapon equip alongside attacks), `spell_cost_multiplier`, mage armor via `BlessingData.stat_modifiers`. Tomes / learn UI / class affinity loot tags / two-handed offhand lock / spell animations are deferred.

**Alternatives considered:**
- Cantrips as free actions (separate dispatch, no turn end): rejected — violates the `execute_action`-as-single-turn-end invariant documented in [[design.md]]; adds a branch that has to be maintained across all casting contexts.
- `spell_cost_multiplier` as a derived stat via `Enums.Stat`: considered, but spell cost is not a character stat — it's a scaling coefficient that belongs on item data and is only relevant at cast time. Keeping it on `EquipmentData` is correct scope.
- Separate `SpellRegistry` node for the spell roster: rejected — the player already owns an analogous `Inventory` with consumable belt patterns. Keeping spell state on `Player` maintains the scoped-ownership principle.

**Rationale:** Reusing `execute_action` / targeting / `Effect.apply` means spell casting inherits all existing infrastructure (targeting indicators, turn sequencing, effect pipeline, save/load hooks) with minimal new code. The consumable-belt → prep-slot isomorphism means the UI pattern and dungeon-lock enforcement are already proven.

**Trade-offs / risks:** `_actions` is a flat namespace; attack and spell names must be globally unique within a run (enforced by `push_warning` at registration). The prep UI in `InventoryPanel` is dynamic (no scene node) — layout is functional but unpolished; needs scene-level positioning once visuals are designed.

---

## Save / Load system

**Date:** 2026-05-05
**Daily:** [[daily/2026-05-05]]

**Decision:** Single-slot auto-save to `user://save.tres` (`RunSaveData extends Resource`). Save fires after every event completion (after rewards are applied). Permadeath: save is cleared on death and on victory. Players can start a New Run (with confirmation if a save exists) or Continue from the main menu.

**Alternatives considered:**
- JSON (`user://save.json`): simpler to inspect but loses static typing and schema drift protection; doesn't fit the Resource-heavy codebase.
- Regenerating dungeon event configs on load: cheaper but unsafe — `DungeonMapNode.generate_event_configs()` uses `randi()` and is non-deterministic. Scene paths + data dicts are stored in the save instead.
- Mid-event saves: deferred to a later pass. The save-on-event-complete design makes this out of scope for v1.

**Rationale:** Resource-based save is consistent with how all authored data (`EquipmentData`, `BlessingData`, etc.) is already handled. Serialisation delegates to the entities themselves (`Player.to_save_dict` / `apply_save_dict`, `Inventory.to_save_dict` / `apply_save_dict`) honouring the "Player owns everything about itself" principle from the 2026-05-02 design session.

**Trade-offs / risks:**
- `StatusInstance.source` (Node ref) cannot be serialised. It is null after load; `StatExprEval` falls back to zeros for source stats. Safe for all authored flat-expression statuses.
- World map node identity is by NodePath relative to the WorldMap node. If the `.tscn` graph is edited between sessions, stale paths log a warning; the save is not automatically invalidated (silent data loss risk if a node is renamed).
- Save schema version is `RunSaveData.VERSION = 1`; mismatches discard the file.

---

## Effect System v2: lifecycle signal bus, statuses, blessings, and equipment procs

**Date:** 2026-05-02
**Daily:** [[daily/2026-05-02]]

**Decision:** Expand the Effect pipeline along three axes without changing the core `Effect.apply(source, target)` contract:

1. **Lifecycle signal bus on `game.gd`.** `game.gd` publishes a comprehensive set of lifecycle signals covering every game-state and turn-state transition: `player_turn_started`, `player_turn_ended`, `enemy_turn_started(enemy)`, `enemy_turn_ended(enemy)`, `event_started(event)`, `event_completed(event)`, `combat_wave_started`, `combat_wave_completed`, `player_attack_hit(attack_data, targets)` (re-emit), `enemy_attack_hit(enemy, damage)` (re-emit), `player_damaged(amount)`, `enemy_damaged(enemy, amount)`, `enemy_died(enemy)`, `consumable_used(data)`. Statuses, blessings, and equipment procs subscribe to whichever signals they need; nothing else owns its own tick loop.

2. **`Combatant` base / mixin.** Extract `_active_buffs`, `_active_statuses`, `apply_buff`, `apply_status`, `remove_status`, `_tick_statuses`, `get_effective_stat`, and the buff/status signals into a shared `Combatant` base (or composition node — to be decided at implementation time; prefer the lower-churn option). Player and Enemy each connect their own status tick to the appropriate `*_turn_ended(self)` signal from the bus. Enemy gains full parity — `BuffEffect` against an enemy stops being a no-op.

3. **Status as a tagged, Effect-driven entity.** A new `StatusData` resource holds:
   - `tag: StringName` — e.g. `"poison"`, `"bleed"`, `"stun"`, `"regen"`, `"burn"`
   - `display_name: String`, `icon: Texture2D`
   - `duration: int` — turns; `-1` = permanent (used internally by on-equip statuses)
   - `stat_modifiers: Dictionary` — optional flat stat layer while active
   - `prevents_action: bool` — combatant skips its turn
   - `on_apply: Effect`, `on_tick: Effect`, `on_expire: Effect` — any may be null
   - `stack_policy: enum { REFRESH, STACK, MAX_DURATION }` — default `REFRESH`

   New `StatusEffect extends Effect` applies a `StatusData` via `target.apply_status(data, source)`. The existing `BuffEffect` becomes a thin wrapper that constructs an inline `StatusData` carrying only `stat_modifiers` and `duration`, so all existing `.tres` files load unchanged.

4. **Run-long blessings live on `Player`.** A new `_blessings: Array[BlessingData]` array on Player, summed into `get_effective_stat()` alongside equipment and active statuses. `BlessingData extends Resource` carries `display_name`, `description`, `icon`, optional `stat_modifiers`, and an optional `subscriptions: Dictionary[StringName, Effect]` mapping bus signal name → Effect to fire when that signal fires. `Player.add_blessing(data)` wires its subscriptions to `game.gd` lifecycle signals; `remove_blessing(data)` disconnects them. Blessings are never ticked. Acquired via `event.rewards.blessings: Array[BlessingData]` (extends the existing reward dict shape) and via `PlayerClassData.starting_blessings`.

5. **Equipment passives — four kinds, all on `EquipmentData`.**
   - `stat_modifiers: Dictionary` — already exists, unchanged.
   - `on_equip_effects: Array[Resource]` / `on_unequip_effects: Array[Resource]` — fired by `Equipment._on_equipped()` / `_on_unequipped()` (currently empty extension hooks, `equipment.gd:42-47`).
   - `proc_effects: Array[ProcDef]` — `ProcDef` holds `trigger: StringName` (a bus signal name), `chance_expression: String` (default `"1.0"`), and `effect: Effect`. On equip, the Equipment node subscribes to `game.gd` for each proc's trigger; the handler rolls the chance and calls `effect.apply(player, target_from_signal_payload)`.
   - `conditional_modifiers: Array[ConditionalModifier]` — `{stat, amount_expression, guard_expression}`. `Player.get_effective_stat()` evaluates each guard via `StatExprEval` per call; if true, the amount is summed in. Per-call cost is bounded by `StatExprEval`'s compile cache.

**Context:** The current Effect pipeline handles one-shot active application (damage, heal, flat-N-turn buff) but is inert for reactive gameplay. Enemies have no buff system — `BuffEffect` against an enemy silently no-ops. There is no concept of named statuses with rich behaviour (Poison ticks per turn, Stun skips a turn, Bleed procs on hit). Equipment cannot react to combat events. There is no run-state layer for permanent boons. Addressing each gap in isolation would invent separate tick loops and subscription mechanisms, producing several uncoordinated event systems. Unifying around a single lifecycle signal bus on `game.gd` lets every reactive system share one pattern: subscribe to a signal, run an Effect.

**Alternatives considered:**

- **(a) Extend `_active_buffs` schema in-place** with `on_tick_callable`, `prevents_action`, etc. Rejected: leaves enemies without parity, doesn't unify equipment procs or blessings, and `Array[Dictionary]` grows unwieldy. `StatusData` as a Resource is authorable in `.tres` files.
- **(b) Per-system signal bus** (Player has its own, Enemy its own, equipment its own). Rejected: every new feature must wire into N buses; cross-system rules ("blessing X buffs whenever an enemy is poisoned") are impossible without bridges.
- **(c) Hardcoded status enum** with behaviour in code. Rejected — per established direction, the Effect pipeline is preferred over enum dispatch (see effect-pipeline entry, 2026-04-27).
- **(d) `RunState` node sibling to `DialogueConsequences`** for blessings. Rejected: Player owns "everything about itself" so save/load has one authoritative source (user decision, 2026-05-02).
- **(e) Autoload event-bus singleton.** Rejected: `game.gd` is already the orchestrator; a parallel autoload duplicates that role and violates the established "game.gd is the brain" invariant.

**Rationale:** The lifecycle signal bus is the load-bearing idea — once it exists, statuses, blessings, equipment procs, and future reactive systems all collapse into the same pattern: a Resource naming a signal and carrying an Effect. New reactive content is authored entirely in `.tres` files. A `Combatant` base eliminates the Player/Enemy asymmetry. `StatusData` cleanly absorbs existing `_active_buffs` semantics (flat-stat-for-N-turns is `StatusData` with only `stat_modifiers`) while also expressing Poison (`on_tick = DamageEffect`), Stun (`prevents_action = true`), and Regen (`on_tick = HealEffect`). Blessings on Player keep run-state authoritative on the entity that survives the run; the `subscriptions` dict makes reactive blessings a one-line authoring task. Equipment proc/conditional types reuse `StatExprEval` for chance rolls and guards, consistent with all other formula evaluation.

**Implementation phases (deferred — see [[daily/2026-05-02]]):**

1. Lifecycle signal bus on `game.gd` — declare signals, emit at existing transition points; add `Subscription` helper (`scripts/subscription.gd`). Behaviour-neutral.
2. `Combatant` base/mixin — extract from Player; Enemy adopts. Verify combat unchanged.
3. `StatusData` + `StatusEffect` — author MVP statuses (poison, bleed, stun, regen); convert `BuffEffect` to wrapper; fix `_recalculate_max_health()` omission; replace `buff_applied`/`buff_expired` with `status_applied`/`status_expired`.
4. Status HUD — icon row with duration counters; `prevents_action` wired into turn loop.
5. Equipment passives — all four kinds on `EquipmentData`; subscription wiring in `Equipment`.
6. Blessings — `BlessingData`; `Player.add_blessing`/`remove_blessing`; `event.rewards.blessings`; `PlayerClassData.starting_blessings`.
7. Save/load shape — verify `_active_statuses` and `_blessings` as `Resource` arrays serialise cleanly.

**Trade-offs / risks:**

- **Signal-bus surface area.** Many signals; each must emit at the right point. Mitigation: `game.gd` emits only (never consumes its own bus); subscribers own connect/disconnect. Document the full contract in the `game.gd` header.
- **Subscription leaks.** Every status/blessing/proc holds a `game.gd` connection. Must disconnect on removal/expiry/unequip. Mitigation: `Subscription` helper (signal + callable pair); removal is mechanical.
- **Stack semantics require per-status authoring.** Default `REFRESH` is correct for most cases; `STACK` (e.g. Bleed) must not crash the HUD. Mitigation: cap *visible* stack count in HUD; logic stays uncapped.
- **`apply_buff` doc/code drift.** `character.md:530` claims `apply_buff` emits `stats_changed`; actual `player.gd:399` does not call `_recalculate_max_health()` — CON buffs do not update max HP until next equip change. Fix in phase 3.
- **Conditional modifier per-frame cost.** Bounded by `StatExprEval` compile cache; dirty-flag optimisation available later if needed.
- **Phase ordering is strict.** Each phase must land independently and pass existing combat (Skeleton, SkeletonLord) before the next begins. Do not interleave.

---

## AnimationPlayer as the single animation driver; AnimatedSprite2D as a passive renderer

**Date:** 2026-05-01

**Decision:** `AnimationPlayer` is the single timeline driver for every animated entity. `AnimatedSprite2D` holds sprite frames but is never called from script — instead, `AnimationPlayer` clips drive it via method tracks (`Sprite.play("idle")` etc.). Scripts hold one `_anim_player` reference, call `_anim_player.play(clip_name)`, and react to `animation_finished(name)`.

**Context:** Animation was split across two systems: `AnimatedSprite2D` drove idle/hit/death directly from script; `AnimationPlayer` drove the attack via a method track. This meant two separate `animation_finished` handlers per entity and no way to layer additional effects (modulate, scale, hitstop, screen shake, pauses) without more ad-hoc code. Adding a longer post-death pause, a scale punch on impact, or a frame-timed SFX cue required the timeline model that `AnimationPlayer` provides.

**Alternatives considered:** (a) Keep the hybrid — cheap but blocks every effect the user wants to add. (b) Fully drive `AnimatedSprite2D.frame` via property tracks rather than calling `Sprite.play()` — more precise frame control but defeats the SpriteFrames speed/duration authoring already in place.

**Rationale:** The attack clip already used this pattern (method track → `Sprite.play()`). Extending it to idle/hit/death is uniform and low-risk. Scripts become thinner: one connection, one handler, one call site. Clip length in `AnimationPlayer` becomes the truth source for timing — a post-death pause is a timeline extension, not a code timer. Layered effects (scale, modulate, screen-shake method calls) can be added per-clip in the Godot editor without touching script.

**Trade-offs / risks:** Per-weapon attack durations are now baked into `weapon.tscn`'s `AnimationLibrary` (currently a single 0.2s clip). If different weapons need different swing timings, the path is a `WeaponData.animation_library: AnimationLibrary` field that `Weapon._ready()` assigns — out of scope for now but the design supports it cleanly.

---

## Effect pipeline: composable, data-driven attack effects via Expression formulas

**Daily:** [[daily/2026-04-27]]

**Decision:** Attack effects are modelled as a `Effect` base `Resource` with a virtual `apply(source, target)` method, subclassed per behaviour (currently only `DamageEffect`). Each `AttackData` carries an `effects: Array[Resource]` that is iterated by `game.gd` across all resolved targets. `DamageEffect` stores a `damage_expression: String` (e.g. `"strength * 0.5"`) evaluated at runtime using Godot's `Expression` class against the source's six stats as named variables. The array is typed `Array[Resource]` rather than `Array[Effect]` throughout.
**Date:** 2026-04-27
**Context:** The previous attack flow was hardcoded — `game.gd._on_player_attack_action` hit the first living enemy for a flat damage value computed inside `player._calculate_damage()`. Introducing per-weapon attack moves (Slash, Cleave, future status effects) required a data-driven pipeline where the formula and behaviour could be authored in `.tres` files without touching GDScript.
**Alternatives considered:** (a) Hardcode damage branches as an enum on `AttackData` (`DAMAGE_FLAT`, `DAMAGE_STR_HALF`, etc.) — rejected: every new formula requires a code change and a new enum value; Expression removes that ceiling. (b) `Array[Effect]` typed export — rejected: Godot's `.tres` serializer can represent `Array[Resource]` unambiguously, but `Array[Effect]` with a custom class_name type produces ambiguous text serialization and can lose sub-resource references when the script is reloaded before the resource. `Array[Resource]` with explicit `as Effect` casts at call sites avoids this entirely. (c) Subclass per attack formula (`SlashEffect`, `CleaveEffect`) instead of an expression string — rejected as over-engineering; Expression handles arbitrary stat combinations at authoring time with no extra code.
**Rationale:** `Effect.apply(source, target)` is the smallest possible contract — two nodes, no return value. It lets `DamageEffect`, future `StatusEffect`, `HealEffect`, etc. live in separate files without any changes to the pipeline in `game.gd` (which just iterates `attack_data.effects` and calls `apply`). `Expression` compilation is cached on the `DamageEffect` instance and only re-runs if the string changes, so there's no per-frame cost. Binding stats by name (`["strength", "defense", ...]`) rather than by position makes formulas self-documenting for authors.
**Trade-offs / risks:** `Array[Resource]` is less type-safe at the GDScript level — a mis-authored `.tres` that puts a non-Effect resource in the array will fail silently (the `as Effect` cast returns null, and `apply` is never called). A `push_warning` in the loop would catch this, but hasn't been added yet. `Expression` evaluates GDScript-like syntax; inputs are author-controlled `.tres` files (not player input), so there is no injection risk, but a malformed expression string produces a silent 0.0 damage via the `has_execute_failed()` guard. To add a new effect type: create a new script extending `Effect`, override `apply()`, and assign the new `.tres` in any `AttackData.effects` array — no changes needed to `game.gd`, `AttackData`, or the turn loop.

---

## Consumable belt: single-use items dispatched outside the action registry

**Daily:** [[daily/2026-04-20]]

**Decision:** Consumables are a new `ConsumableData` subclass of `EquipmentData`, stored on `Inventory` in a variable-size `_consumable_belt: Array` (index-based, may contain nulls) alongside — but separate from — the existing bag. Unequipped consumables share the main `_bag` with weapons, armor, and rings; the belt is the "equipped" projection. Belt size is driven by `PlayerClassData.starting_consumable_slots`; `Inventory.set_belt_size(n)` supports runtime resize (spilling overflow to the bag) and emits `belt_size_changed` for the UI. Single-use semantics: activation destroys the item, leaving the slot empty until re-equipped outside combat. Four MVP effect types — `HEAL_FLAT`, `HEAL_PERCENT`, `DAMAGE_ALL`, `STAT_BUFF`. Activation is routed by a new `gui.consumable_use_requested(index)` signal into a new `game.gd._on_consumable_use_requested(index)` dispatcher, which validates state ∉ {ENEMY_TURN, GAME_OVER, VICTORY}, applies the effect via a per-branch match (`player.heal`, `player.apply_buff`, `CombatEvent.apply_consumable_damage`), calls `Inventory.consume(index)`, and emits `player.consumable_used` for log/SFX. The dispatcher **deliberately does not go through `player.execute_action()` and never sets `_turn_pending` or emits `turn_ended`** — that way the player can drink a potion or throw a bomb without surrendering the turn to enemies. Combat UI adds a `ConsumableBelt` HBoxContainer inside `ActionMenu` with one button per belt slot, rebuilt from `Inventory.consumable_belt_changed` / `belt_size_changed`. Usage is permitted during `PLAYER_TURN`, `NO_TURN`, and `DIALOGUE`; `game.gd` flips a new `gui.set_consumables_enabled()` independently of `set_player_turn()` so the belt stays active outside the strict player turn. Buffs from `STAT_BUFF` effects are tracked on Player as `_active_buffs: Array[{stat, amount, turns_remaining}]`, tick down once per player turn (just before `turn_ended.emit()`), and are summed into `get_effective_stat()` alongside equipment modifiers.
**Date:** 2026-04-20
**Context:** The game had no mid-combat utility options. Every player action today ends the turn; there was no way to spend a resource to heal, buff, or AoE without forfeiting initiative. The combat loop needed a "quick slot" channel for disposable items, and the equipment/inventory infrastructure was the natural place to host it. Yesterday's daily log closed with "Plan consumables system" — this design is the answer.
**Alternatives considered:** (a) Add an `ends_turn: bool` parameter to `register_action()` / `execute_action()` and register consumables as non-turn-ending actions — rejected: muddies the action registry's single invariant ("actions end turns") and risks future actions being mis-tagged. (b) Special-case the consumable branch inside `execute_action()` to skip `_turn_pending` — rejected: breaks the explicit CLAUDE.md rule "`execute_action()` is the single point that emits `turn_ended`" and scatters turn-ending logic. (c) Separate consumable pouch with its own bag — rejected: duplicates bag-management code and storage rules (capacity, spillover) with no gameplay benefit. (d) Multi-charge or stackable consumables — rejected for MVP: single-use keeps loadout decisions sharp (one slot = one use = one careful choice), and stacking can be layered in later via a per-item `charges` field without re-architecting. (e) `ConsumableBelt` as a standalone HUD overlay (always visible, outside `CombatHUD`) — deferred: fine idea given that usage is allowed outside combat, but scoping it inside `CombatHUD` for MVP keeps the HUD tree change minimal. Flagged as an open question in [[detailed/gui-design.md]]. (f) Per-consumable `combat_only: bool` flag to disable buttons when context doesn't match — deferred: MVP no-ops `DAMAGE_ALL` outside combat rather than hiding the button; we can tighten later if players find it confusing.
**Rationale:** Dispatching from `game.gd` rather than the action registry preserves the "one source of `turn_ended`" invariant verbatim — no registry changes, no new flags, no risk of a future action forgetting to declare itself turn-ending. The belt mirrors the existing ring pattern (index-based fixed-size array with nullable entries, auto-fill equip helper, emit-on-change signal) so `Inventory` code and `InventoryPanel` UI extend by analogy. Single-use semantics match typical roguelike potion conventions and avoid the bookkeeping of charge counters or per-slot stacks. Routing `DAMAGE_ALL` through `CombatEvent.apply_consumable_damage()` respects the "Player doesn't reach into enemies" rule — Player only emits `consumable_used`; combat-aware damage application lives with the event that owns enemies. Buff tracking on Player (rather than on consumables as nodes) keeps the `EquipmentData → Equipment node` distinction clean: consumables are pure data, consumed once, never leaving an `Equipment` scene on the tree.
**Trade-offs / risks:** Empty belt slots take persistent HUD space (mitigated: greyed buttons are a legible "you spent this, loadout is thinner now" signal). `DAMAGE_ALL` used outside combat silently no-ops — acceptable MVP behaviour, not error-state; documented. Buff stacking is rudimentary (plain additive, no caps, no diminishing returns) and may allow unintended optimization if buff consumables become plentiful — flagged as tuning concern, not a design one. `ConsumableBelt` lives inside `CombatHUD`, so the "usable anywhere except enemy turn / game-over" decision is partially undermined — players can't press the belt on the world map until the overlay question is resolved. Save/load must eventually serialize `_active_buffs` alongside `_consumable_belt`; out of scope for this pass but noted.

**Update (2026-04-29):** The hardcoded `EffectType` enum and `_apply_consumable_effect` match block have been replaced with the unified `Effect` pipeline already used by attacks. `ConsumableData` now carries `effects: Array[Resource]` and a `target_mode: TargetMode` (SELF / ALL_ENEMIES) in place of the scalar fields. `game.gd._apply_consumable_effect` iterates effects exactly as `_on_player_attack_performed` does; `_resolve_consumable_targets` handles the SELF / ALL_ENEMIES split. `CombatEvent.apply_consumable_damage` was deleted — `DamageEffect` (flat expression `"40"`) applied per-enemy achieves the same result. New subclasses: `HealEffect` (expression evaluated against target, with `max_health`/`health` vars) and `BuffEffect` (stat + amount expression + duration). The non-turn-ending invariant is fully preserved — the dispatcher path is unchanged above `_apply_consumable_effect`.

---

## Rewards follow player choice, not event identity

**Daily:** [[daily/2026-04-19]]

**Decision:** `DialogueEvent` and `SkillCheckEvent` no longer declare rewards at the event level. Dialogue rewards live on **terminal nodes** (empty `choices`) of the dialogue tree as an optional `rewards: { experience, gold }` dict; `DialoguePanel` now emits `dialogue_complete(terminal_node_id: String)`, and `DialogueEvent.on_dialogue_complete(terminal_node_id)` populates the inherited `rewards` field from that node before `_advance_phase()`. SkillCheckEvent replaces its flat `rewards` with `rewards_on_success` / `rewards_on_failure`; `_on_resolution()` picks the right dict based on `_success` at its first line, so rewards are set even when no result dialogue fires. No event-level fallback — paths without declared rewards grant nothing. `game._apply_rewards()` is untouched; it still reads `current_event.rewards` at `_on_event_complete()`.
**Date:** 2026-04-19
**Context:** Every branch through a dialogue tree, and every outcome of a skill check, paid out the same flat reward. The branching itself was meaningful for flavor (flags, consequences) but not for progression, which undermines the point of giving the player a choice.
**Alternatives considered:** (a) Extend the existing `DialogueConsequences` dispatcher with a `give_experience` action and fire rewards via node `consequence` blocks — rejected because nodes currently support only one consequence, and authors frequently want to pair a flag with a reward at the same path end. (b) Keep an event-level default `rewards` as a fallback when no terminal node specifies one — rejected to avoid two sources of truth; every rewarding path must declare itself. (c) Accumulate rewards along the path (sum of every visited node) — rejected as too easy to author accidentally imbalanced outcomes; only the chosen path-end pays.
**Rationale:** Terminal-node `rewards` reuses the event's inherited `rewards: Dictionary` field, so `game._apply_rewards()` and the event phase machine need no changes — the only new information is "which terminal node did the player stop on," and `DialoguePanel` already tracks `_current_node_id`. For SkillCheckEvent, setting `rewards` at the top of `_on_resolution()` keeps reward selection co-located with the rest of the per-outcome branching (which dialogue path to show) and handles the "no result dialogue" case without a second code path. Skill-check flavor dialogues intentionally ignore any terminal-node `rewards` — the skill check owns its reward domain.
**Trade-offs / risks:** Signal signature change on `dialogue_complete` ripples through `dialogue_panel.gd`, `gui.gd`, and `game.gd` — SkillCheckEvent and CombatEvent branches now receive a `terminal_node_id` they don't consume (harmless but asymmetric). Authors must remember to add `rewards` explicitly; forgetting yields a silent zero-reward path rather than a default. Mid-tree `consequence` side effects (e.g. `give_gold`) still fire and stack with terminal-node rewards, which is intentional but must be accounted for when tuning economy.

---

## Game-end system: VICTORY state + BossEvent intercepts at the event layer

**Daily:** [[daily/2026-04-17]]

**Decision:** Game over and victory are two distinct terminal flows. **Game over** is triggered by `player.died` in any event; `game.gd._on_player_died()` sets `state = GAME_OVER`, calls a new shared helper `_teardown_current_event()` to clean up whatever event was active, then calls `gui.show_game_over()`. **Victory** is triggered by an explicit new event subclass `BossEvent extends CombatEvent`, placed on a new `NodeType.BOSS` world-map node. BossEvent overrides `_advance_phase()` so that when all enemies die it emits a dedicated `boss_defeated` signal instead of transitioning to RESOLUTION/COMPLETE; `event_complete` is intentionally never emitted on boss victory. `game.gd._on_boss_defeated()` sets `state = VICTORY`, applies rewards off the event, tears it down, nulls all dungeon-progress state (skipping `_on_dungeon_complete` entirely), shows the level-up panel if points are pending (so the player can allocate the final earned points), then shows the victory panel. Both GameOverPanel and VictoryPanel emit a unified `main_menu_requested` intent that `gui.gd` re-emits as the existing `quit_to_main_requested`, routing to `game.quit_to_main()`. A shared `_teardown_current_event()` extracted from `_on_event_complete()` is called by the normal completion path, the death path, and the victory path so cleanup stays symmetric across all three terminations.
**Date:** 2026-04-17
**Context:** The game had no terminal states. `player.died` set `state = GAME_OVER` but no UI responded and gameplay hung. Finishing every world-map node just looped back to the map. Two things were needed: a loss flow, and an explicit win flow. The user specifically did not want the win to be detected programmatically ("is this the last event?") — it should be a deliberate design decision per-map, marked by an explicit node type and event type.
**Alternatives considered:** (a) Flag on CombatEvent data (`is_final_boss: bool`) reusing the existing combat scene — rejected for mixing terminal-flow concerns inside CombatEvent and making the win path implicit in JSON. (b) Standalone `BossEvent extends Event` that reimplements combat — rejected for duplicating enemy-spawn and turn-resolution logic. (c) Intercepting victory at `_finish_event()` with a `state == VICTORY` guard — rejected because it smears terminal logic across two functions and still routes through `_on_dungeon_complete → world_map_on_dungeon_complete`, which incorrectly marks the node COMPLETED and re-shows the map. (d) Flag on WorldMapNode (`is_boss_node: bool`) — rejected for muddying the `node_type` contract with a parallel boolean.
**Rationale:** BossEvent as a `CombatEvent` subclass is the cheapest possible structural change — all enemy, HUD, music, and per-event signal wiring is inherited for free via the existing `event is CombatEvent` branch in `start_event()`. Only one extra connection is needed (`boss_defeated` on an `event is BossEvent` check). A dedicated terminal signal at the event layer (rather than overloading `event_complete`) keeps victory handling in one dedicated function, skips the reward-→-level-up-→-next-event pipeline that doesn't apply when the run is over, and avoids the wrong-semantics problem of `_on_dungeon_complete` re-showing the map. A new `NodeType.BOSS` mirrors the existing SHOP/REST handling in `world_map_node.gd` exactly — `_build_boss_config()` alongside `_build_rest_config()` and `_build_shop_config()`. Unified `main_menu_requested` → `quit_to_main_requested` preserves the one-intent-one-destination principle; both panels ask game.gd to do the same thing, so they feed the same signal. The shared `_teardown_current_event()` helper is the load-bearing refactor — it fixes the "GAME_OVER does nothing" bug, makes the death flow symmetric with normal completion, and gives victory a clean path to reuse existing disconnect logic without duplication.
**Trade-offs / risks:** BossEvent deliberately does not emit `event_complete` on win, which is a minor reinterpretation of the event contract — previously, every event emitted `event_complete` when done. The contract is now "events emit `event_complete` OR a dedicated terminal signal when done." Documented in [[detailed/event-system.md]]. Multiple BOSS nodes on one map are mechanically allowed but any `boss_defeated` ends the run; if future design wants a mid-run boss-tier encounter that doesn't terminate, that will require a distinct subclass. `quit_to_main()` currently does not reset player state (HP/XP/gold/inventory) — relevant when starting a new run after death/victory. Not resolved here; flagged in the plan as an implementation-time check (`_on_character_created` may already do enough on a fresh character create).

---

## Shop transactions route through game.gd, not the panel or the event

**Daily:** [[daily/2026-04-14]]

**Decision:** For the upcoming `ShopEvent` / `ShopPanel`, all validation and state mutation for buy/sell transactions live in `game.gd`. `ShopPanel` emits intent signals (`buy_requested`, `sell_requested`, `leave_requested`) with only an `EquipmentData` payload; `GUI` re-emits them; `game.gd` reads `player.gold`, validates price and bag capacity, calls `player.spend_gold` / `player.add_gold`, mutates the bag via `inventory.add_to_bag` / `remove_from_bag`, and tells `ShopEvent` what happened via `on_buy(item)` / `on_sell(item)` so it can update its `_stock`. `ShopPanel` holds no references to `Player`, `Inventory`, or `ShopEvent`.
**Date:** 2026-04-14
**Context:** Designing the shop node type. The natural shortcut was to pass `player` and `shop_event` into `shop_panel.setup()` so the panel could compute prices, check the bag, and mutate state directly. This would have violated the "Passive GUI" rule (2026-03-12) and the "`game.gd` is the sole class that holds a `var player` reference" rule (2026-03-01).
**Alternatives considered:** (a) Panel holds direct refs to player/event and performs transactions; (b) `ShopEvent` holds the player reference and `game.gd` just routes signals; (c) a transaction service class.
**Rationale:** This matches the established `SkillCheckEvent` pattern — "`game.gd` is the only place `player.get_effective_stat()` is called… the event never holds a player reference." Keeping all policy (enough gold? bag full?) in `game.gd` means the shop behaves exactly like every other event: event requests a UI, UI emits intents, game.gd decides, game.gd tells the event the result. No new architectural patterns.
**Trade-offs / risks:** `game.gd` grows another handler set (`_on_gui_shop_buy_requested`, etc.) and has to explicitly pass state through on every refresh (stock, bag, gold, `bag_full: bool`) rather than the panel reading from live references. Accepted — explicit data flow is easier to trace than implicit reference-based reactivity, and the pattern is already established for every other panel.

---

## UI Architecture — Passive GUI with Intent-Based API

**Daily:** [[daily/2026-03-12]]

**Decision:** Use a single CanvasLayer as the top-level UI node, with sections (CombatUI, PauseMenu, MainMenu, etc.) as children. A `gui.gd` script exposes an intent-based API. `game.gd` drives all UI changes via direct method calls.
**Date:** 2026-03-12
**Context:** Starting to build out the UI layer. Needed to establish how game state and input connect to the display before writing any UI code.
**Alternatives considered:**
- Signal-driven (game emits, GUI connects) — rejected because the GUI would need to interpret signals and make display decisions, leaking intent into what should be a passive layer.
- Autoload UI manager singleton — unnecessary indirection at this project scale.
**Rationale:** The GUI has no independent existence — it is a direct output of game state. `game.gd` is the brain; the GUI is its display. Direct method calls reflect that coupling honestly. Signals are reserved for genuinely loosely coupled systems (e.g., `player.damaged` → `gui.update_health()`, wired by `game.gd`).
**API design:** Methods are intent-based, not imperative. `game.gd` calls `gui.handle_esc()`, not `gui.show_section("pause")`. The GUI owns the *how* — which sections to toggle, transitions, etc. `game.gd` owns the *when* — input capture and game state decisions.
**Trade-offs / risks:** `game.gd` holds a direct reference to the GUI, creating a hard dependency. Acceptable given the GUI's role as a direct output of game state.

---

## POV Sprite Export Resolution

**Daily:** [[daily/2026-03-08]]

**Decision:** All player POV sprites (weapons, hands) are exported at 480x270 to match the internal pixel art reference resolution.
**Date:** 2026-03-08
**Context:** The game runs at 1920x1080 or higher, but we needed a fixed export size for POV sprites so that Godot's upscaling preserves the retro pixel art aesthetic. Tested 480x270 in-engine and confirmed it looks correct.
**Alternatives considered:** No formal alternatives evaluated — 480x270 was tested directly and accepted on visual merit.
**Rationale:** Exporting at 480x270 captures the sprite at the exact scale it should appear from the player's POV. Upscaling from this resolution to the display resolution produces the desired pixel art look without additional filtering or engine tricks.
**Trade-offs / risks:** If the reference resolution ever changes, all POV sprites need to be re-exported. Low risk in practice because assets are rendered from 3D models, so re-rendering at a new size is straightforward.

---

## Signal-based attacks and player reference isolation

**Daily:** [[daily/2026-03-01]]

**Decision:** Player and Enemy both emit `attacked(damage: float)` signals when they act rather than calling `take_damage()` directly on a target reference. `game.gd` is the sole class that holds a `var player` reference. Events expose `receive_player_attack(damage)` for routing player damage to the appropriate enemy, and emit `player_attacked(damage)` for routing enemy damage back to `game.gd`. `Event.start()` takes no arguments — events no longer receive a player reference at all.
**Date:** 2026-03-01
**Context:** The original design passed target nodes across ownership boundaries: `enemy._perform_action(target: Node)` called `target.take_damage()` directly via duck typing, `player._do_attack(target: Node)` did the same, and `event.start(player: Player)` spread the player reference into the event layer. This created tight coupling and violated the principle that `game.gd` should be the sole owner of the player.
**Alternatives considered:** Typed `Combatant` base class with a shared `deal_damage(target: Combatant)` method; keeping direct calls but enforcing typed parameters; a central event bus.
**Rationale:** Godot best practices strongly favour loose coupling via signals. Neither combatant needs to know what it's hitting — the event layer owns target selection for player attacks, and `game.gd` owns damage application to the player. This makes both Player and Enemy independently testable and keeps all player-touching code in one place.
**Trade-offs / risks:** Adding a new action type that needs to target something specific (e.g. a heal targeting a specific ally) requires extending the signal/routing pattern rather than passing a direct reference. `execute_action()` no longer accepts a target parameter, so action callables must pull context from signals or event state rather than receiving it directly.

---

## Visual style — pixel art rendered from 3D models

**Daily:** [[daily/2026-03-01]]

**Decision:** Sprites are produced by rendering 3D models into pixel art frames rather than hand-drawn pixel art or ASCII art. Each enemy and character is modelled, rigged, posed, and exported as a spritesheet per state (idle, attack, hurt, death).
**Date:** 2026-03-01
**Context:** Needed to commit to a visual style before building the UI and enemy display systems. ASCII art was the implicit placeholder; pixel art from 3D renders was explored as an alternative.
**Alternatives considered:** ASCII art (terminal-style); hand-drawn pixel art; full 3D in-engine rendering.
**Rationale:** Pixel art from 3D renders gives consistent proportions and lighting across all characters without requiring hand-drawing skill for every asset. The skeleton enemy was the first asset produced under this approach and confirmed the style is achievable and looks good. It also sets a replicable pipeline for future enemies.
**Trade-offs / risks:** Asset production requires a 3D modelling and rigging step before any in-game sprite exists. Pipeline (model → rig → pose → render → import) needs to stay consistent across all characters or visual coherence breaks. Sprite resolution and palette should be standardised early.

## Scoped state ownership — enemies belong to events, player belongs to game.gd

**Daily:** [[daily/2026-02-22]]

**Decision:** The player reference lives on game.gd and persists across all events. Enemy references live on the event that spawned them and are gone when the event ends. Events receive the player as an argument on `start(player)` for the duration of the encounter.
**Date:** 2026-02-22
**Context:** game.gd previously held both player and enemy references. Enemies are transient (encounter-scoped); centralising them in game.gd means teardown has to happen there too, and game.gd accumulates knowledge it shouldn't need.
**Alternatives considered:** All participants owned by game.gd; all participants owned by the event (including player).
**Rationale:** Ownership follows logical lifetime. The player persists across a full run — save state, stats, inventory all live there. Enemies exist for one encounter. Keeping enemies on the event means signal wiring, wave tracking, and teardown are all self-contained; when the event is freed, all of that goes with it cleanly. game.gd stays thin.
**Trade-offs / risks:** Events need to communicate outcomes back to game.gd (loot gained, XP earned, player health after combat) through the `event_complete` signal payload or a result object rather than game.gd reading state directly. That contract needs to be defined consistently across event types.

---

## Event state machine with virtual phase hooks

**Daily:** [[daily/2026-02-22]]

**Decision:** Events are implemented as a base `Event` class with a fixed phase enum (`SETUP → RUNNING → RESOLUTION → COMPLETE`) and virtual hooks (`_on_setup()`, `_on_running()`, `_on_resolution()`) that subclasses override. The base class owns phase transition logic and emits `event_complete` when done; game.gd waits for that signal without ever inspecting phase state directly.
**Date:** 2026-02-22
**Context:** Event types need to be independently complex (e.g. a combat event with pre-fight dialogue, multiple enemy waves, and a post-fight loot phase) without that complexity leaking into game.gd or requiring architectural changes later.
**Alternatives considered:** Base class with a single virtual `load(game)` method; signal-driven event bus; flat match statement in game.gd per event type.
**Rationale:** A fixed phase scaffold on the base class means all events speak the same language to game.gd, while subclasses have full freedom inside each phase hook. A `CombatEvent` can loop back through `RUNNING` for additional waves internally — game.gd never knows or cares. New event types are a new file with no changes to the host.
**Trade-offs / risks:** The fixed phase order may not fit every event type naturally. Phases that don't apply to a subclass just get empty overrides, which is fine, but if events need radically different flow the base enum may need revisiting.

---

## Explicit participant setup over scene-tree auto-collection

**Daily:** [[daily/2026-02-22]]

**Decision:** Player is set via `set_player()` and enemies are loaded via `load_combat_event()` rather than auto-discovered from scene children in `_ready()`.
**Date:** 2026-02-22
**Context:** Auto-collecting from the scene tree works for a static test scene but breaks down when participants come from save data, procedural dungeon generation, or event-driven encounter loading.
**Alternatives considered:** `@onready` node path references; scanning `get_children()` at startup.
**Rationale:** `set_player()` can be called at startup or after loading a save with no code change. Event classes call `load_*_event()` to hand off their participant data when an encounter begins — game.gd stays passive and reacts rather than pulling. Signal connections happen at the point participants are registered, keeping setup and teardown co-located.
**Trade-offs / risks:** `_ready()` no longer auto-starts anything; callers must explicitly call `set_player` and a `load_*_event` function before the game loop runs. Need to guard against calling turn-flow functions before a player is set.

---

## Player action registry

**Daily:** [[daily/2026-02-22]]

**Decision:** Player actions are stored as a `Dictionary` of `Callable`s and executed via `execute_action(name, target)`.
**Date:** 2026-02-22
**Context:** Player turns need to support multiple actions (attack, spells, items, etc.) without game.gd needing to know about specific methods, and without a growing match/switch block.
**Alternatives considered:** Match statement in game.gd dispatching to named methods; abstract virtual methods per action type; direct method calls from UI.
**Rationale:** A dictionary of callables means new actions are one `register_action()` call — no changes needed in game.gd or the Player class itself. `execute_action` is the single point that emits `turn_ended`, so the turn signal fires exactly once per action regardless of what the action does.
**Trade-offs / risks:** Action names are plain strings — no compile-time safety. Typos will silently do nothing (the `has()` check guards against crashes). Consider defining action name constants if the list grows large.

---

## Enemy AI via override hook

**Daily:** [[daily/2026-02-22]]

**Decision:** Enemy decision-making lives entirely in `_perform_action(target)`, which subclasses override to implement different behaviours.
**Date:** 2026-02-22
**Context:** Different enemy types need different AI without the game manager needing to know the difference between them.
**Alternatives considered:** Strategy pattern (inject an AI object); match on enemy type in game.gd; signal-based action requests.
**Rationale:** GDScript inheritance and virtual method override is the simplest path. game.gd calls `enemy.take_turn(player)` uniformly for every enemy — each type handles its own logic internally. A goblin, a boss, and a passive creature are all just `Enemy` nodes to the game manager.
**Trade-offs / risks:** Deep inheritance trees get hard to manage. If behaviours need to be composed (e.g. an enemy that sometimes charges, sometimes heals), a strategy/component approach may be needed later.

## Signal-based UI/logic separation

**Daily:** [[daily/2026-02-22]]

**Decision:** Player and Enemy emit signals for game events; UI and game manager connect to those signals externally.
**Date:** 2026-02-22
**Context:** Needed an architecture for keeping visual feedback (health bars, combat log) decoupled from game logic (turn order, win/lose conditions).
**Alternatives considered:** Having Player/Enemy directly call UI methods; using a central event bus.
**Rationale:** Signals are Godot's native observer pattern. Emitters don't need references to the UI or game manager — they just fire and let receivers react. All connections live in one place (game.gd), making data flow easy to trace.
**Trade-offs / risks:** Signal connections need to be managed carefully to avoid dangling connections when nodes are freed (use `connect` with `CONNECT_ONE_SHOT` or disconnect on death where needed).
