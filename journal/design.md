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

## Burn = single-turn start-of-turn burst (not a lingering DoT)

**Date:** 2026-07-13
**Daily:** [[daily/2026-07-13]]

**Decision:** Burn is a **one-round burst that discharges its whole stack pool at the start of
the bearer's turn, before it acts** — the opposite of poison's slow drain. Applying N burn = N
stacks; on the bearer's next turn start the pool empties as a countdown (N, N-1, … 1 damage,
one hit per step with a short delay so the health bar visibly steps down), then the status is
removed. Total scales triangularly (3 stacks → 6, 5 → 15), which is burn's "scales big" identity.

Mechanism:
- New data flag `StatusData.burst_on_turn_start`. Burst statuses are **excluded** from the
  per-turn `_tick_statuses()` cadence.
- New async `Combatant.resolve_turn_start_bursts()` walks `instance.stacks` down, reusing the
  existing `DamageEffect.apply_tick` (which already deals `base × stacks`) — so `burn.tres` stays
  a plain `DamageEffect` at `damage_expression = "1"` (raw stack countdown). A delay of
  `BURST_STEP_DELAY` (0.3s) separates hits; `status_ticked` fires each step so the UI stack
  number counts down 3 → 2 → 1.
- `Enemy.take_turn()` `await`s the burst before `_perform_action()`; `Player.begin_turn()` fires
  it too (so enemy-inflicted burn on the player also bursts). A `_is_burst_bearer_defeated()`
  hook (overridden by Player/Enemy via `is_dead`) stops a burst from hitting a corpse.

**Context:** Burn had been implemented as a flat `DamageEffect` ("6" for `duration` turns), which
made it a weaker, longer-lasting poison — no distinct identity. The user wanted the felt
difference: poison lingers and ramps down across turns; burn detonates all at once, up front.

**Alternatives considered:** The earlier plan (this entry supersedes the Fire note below, dated
2026-07-09) had burn as a `BurstDamageEffect` scaling by `turns_remaining`, i.e. 3/2/1 spread
across three *separate* turns. That is still a lingering DoT, just front-loaded — not the
single-turn detonation the user asked for. `BurstDamageEffect` is now unused by burn.

**Trade-offs / risks:** Burn resolution is async (timed), so `take_turn()`/`begin_turn()` now
yield mid-call; the turn loop relies on the existing one-shot `turn_ended` wiring to advance,
which is unchanged. Burst damage still routes through `take_damage`, so the armor buffer can
absorb small per-step hits (consistent with poison). Only burn moves to start-of-turn; poison
and other DoTs keep their end-of-turn ramp.

## Elemental & martial status-verb systems (hybrid: bus subscriptions + per-verb plumbing)

**Date:** 2026-07-09
**Daily:** [[daily/2026-07-09]]

**Decision:** Land the *systems* for the two top [[ideas/elemental-signature-identities]] entries — elemental signatures
(Poison/Fire/Lightning/Frost) and martial verbs (Bleed/Shatter/Brace) — as plumbing only, ready
for `.tres` authoring next. No content authored yet; every new field/behavior defaults to a
no-op, so in-game behavior is unchanged until resources exist. Each mechanism uses the tool that
fits it (**hybrid**), rather than forcing everything through one channel:

- **Status `subscriptions` (bus).** `StatusData.subscriptions: Dictionary` (signal-name → Effect),
  wired to the `game.gd` lifecycle bus on `apply_status` and disconnected on removal / combat-end
  clear / expiry — mirroring `BlessingData.subscriptions` and reusing the `Subscription` helper.
  The bus ref is injected into `Combatant._status_bus` (Player at `set_player`, Enemy at
  `_on_combat_enemy_added`). This is the forward-looking foundation for *reactive* statuses
  (on-damaged, on-kill); none of the six verbs below centrally need it, but it's the requested
  home for future status content and keeps statuses consistent with procs/blessings.
- **Fire — burst DoT** via a new `Effect.apply_tick(source, target, instance)` hook (defaults to
  `apply`, so existing tick effects are untouched). `_tick_statuses` calls it with the owning
  `StatusInstance`; `BurstDamageEffect` reads `instance.turns_remaining` (tick fires *before* the
  decrement, so a `duration:3` burn sees 3→2→1).
- **Frost — armor pierce.** `take_damage(amount, pierce)` / `_apply_defense(amount, pierce)` on
  Player and Enemy; `effective_armor = max(armor - pierce, 0)`. Pierce reduces only *this* hit's
  absorption, leaving the buffer otherwise intact. `DamageEffect` gains `pierce_expression`.
- **Lightning — chain.** `ChainDamageEffect` reaches the array-adjacent enemy via
  `target.get_parent().get_children()` (siblings under `CombatEvent/$Enemies`).
- **Bleed — gated application.** `GatedBleedEffect` deals damage, compares `target.health`
  before/after, and applies its status only if HP actually dropped. Self-contained.
- **Shatter — suppress refresh.** `StatusData.suppresses_armor_refresh`; a guard at the top of
  both `refresh_armor()` bodies covers all three call sites at once.
- **Brace — one-round armor bump.** `BraceEffect` raises `max_armor` and adds to `armor` directly
  (clamped), resetting naturally on the next `refresh_armor`.

**Context:** The status-clear groundwork (2026-07-08) unblocked authoring a wave of status verbs.
The open question was *how effects receive combat context* they don't get from `apply(source,
target)` — Fire needs its own `turns_remaining`, Lightning needs the roster. The user's steer was
to lean on the existing lifecycle signal bus (as procs/blessings already do) rather than widen the
`Effect.apply` contract.

**Alternatives considered:**

- **Widen `Effect.apply(source, target, context)`.** Rejected: churns every effect subclass and
  call site, and changes a documented contract, to serve two narrow needs.
- **Route everything through the bus (bus-first).** Rejected for these six: the global bus fires
  once per round regardless of bearer, so a bus-driven Fire tick desyncs enemy-borne burns from
  their own countdown; and instant attack-effect logic (Bleed's gated hit, Lightning's roster
  reach, Brace) has no natural signal to subscribe to. Kept the bus where it fits (reactive
  statuses) and used the fitting mechanism elsewhere.
- **Skip the subscription capability entirely.** Rejected: reactive statuses are coming, and the
  bus pattern already exists for procs/blessings; building the status counterpart now keeps the
  three consistent and gives authors a ready channel.

**Trade-offs / risks:** The one place this refines the bus steer is Fire's `apply_tick` — a
per-bearer tick belongs on the bearer's own tick loop, not a global signal. Adds four small
`Effect` subclasses and two `StatusData` fields; the subscription infra ships unused by these
verbs (justified as foundation). Save/load wires subscriptions on `apply_status_save_array`, but
`StatusInstance.source` is null post-load, so a reactive effect that reads its source stats sees
zeros — acceptable while authored reactive statuses target the bearer.

---

## Combat-inflicted statuses clear at combat end

**Date:** 2026-07-08
**Daily:** [[daily/2026-07-08]]

**Decision:** `StatusData` gains a `persistence: enum { COMBAT, PERSISTENT }` field (default
`COMBAT`). When any combat ends, the player's `COMBAT`-persistence statuses are swept from
`_active_statuses`; `PERSISTENT` ones survive. The sweep is a new `Combatant.clear_combat_statuses()`,
called from `CombatEvent._on_exit()` — the single choke point every combat exit (victory and
player-death) already funnels through to tear down enemy health bars. Enemies need no sweep;
their nodes are freed with the event. The sweep emits `status_expired` per removed instance (so
the HUD status row clears) and recalcs stats once, but deliberately does **not** fire `on_expire`
— a forced clear is not a natural expiry, and firing arbitrary expire effects into a just-ended
combat is a footgun; this mirrors the existing full-clear paths (`apply_status_save_array`,
`player.reset_run_state`).

**Context:** Combat-inflicted statuses (poison, bleed, burn, stun, buffs) leaked past the fight
that applied them — enemies escaped the bug for free (freed at teardown) but the player's
`_active_statuses` was never swept, so e.g. a lingering poison kept ticking into the next event.
Groundwork for a wave of upcoming status work (Bleed, burst-Burn, Shatter/Brace, elemental
signatures — see [[ideas/elemental-signature-identities]]), all of which need a clean rule for what survives a fight.

**Alternatives considered:**

- **(a) Blanket clear all statuses at combat end.** Rejected: strips legitimate run-permanent
  statuses granted by gear/backgrounds (meant to persist through non-combat events too).
- **(b) Key the clear off `duration == -1`.** Rejected: conflates two independent axes. A planned
  combat status (Bleed) is *also* `duration: -1` (never ticks down) yet must clear at combat end.
  "Does it tick down" and "does it survive combat" are different questions; persistence must be
  explicit and independent of duration.
- **(c) The idea doc's `source: { COMBAT, EQUIPMENT }` naming.** Rejected: `StatusInstance`
  already has an unrelated `source: Node` (the applying node), so `instance.data.source` beside
  `instance.source` is a readability trap; and `EQUIPMENT` under-describes background/blessing
  sources. `persistence`/`PERSISTENT` names the behavioral property and avoids both.

**Trade-offs / risks:** `on_expire` not firing on the forced clear means a status relying on an
expire effect for cleanup won't get it at combat end — acceptable, as combat statuses currently
carry no `on_expire`, and combat-end teardown already resets the relevant context.

---

## DEF is a refreshing per-round armor buffer; AGI dodge decays within a round

**Decision:** Replace the flat-percentage defense and dodge formulas (below, 2026-05-19 —
now **superseded**) on both `Player` and `Enemy`.

- **DEF → armor buffer.** `_apply_defense()` no longer scales damage by `1 - DEF/100`.
  Instead each combatant carries an `armor` buffer (`max_armor` = effective DEF) that
  absorbs incoming damage before HP; only the overflow bleeds through. The buffer refreshes
  to full at the **start of each round** — `player.begin_turn()` for the player;
  `CombatEvent._on_round_started()` (subscribed to `game.player_turn_started`) for every
  living enemy, since enemies take damage during the player's turn. Immunity is impossible
  by construction: a single hit larger than the remaining buffer pierces straight to HP, no
  matter how high DEF climbs. The old 1-damage floor is gone — a fully-absorbed hit deals 0
  and produces no hurt flash/SFX (`armor_absorbed` fires a combat-log line instead).
- **AGI → decaying dodge.** `_roll_dodge()` still reads dodge chance as `AGI/100`, but that
  chance halves once per successful dodge already made **this round** (`_dodge_streak`,
  reset in `begin_turn()`). Only a *successful* dodge decays it, so an unrelated miss (a
  future blind/accuracy debuff) won't. Stops a high-AGI build variance-dodging an entire
  multi-attack round.

New signals: `Player.armor_changed` / `Player.armor_absorbed`, `Enemy.armor_changed`, drawn
by the GUI (`update_player_armor`, `update_enemy_armor`; a `PlayerArmorBar` and an `Armor`
overlay sprite on the enemy `HealthBar`). `armor` / `max_armor` / `_dodge_streak` are
transient combat state and are **not** saved.

**Date:** 2026-07-07
**Daily:** [[daily/2026-07-07]]
**Context:** The flat-percentage formula was legible but degenerate at the ceiling — every
DEF point is a flat 1% with no soft cap, so DEF 100 = literal immunity, and the planned
Sentinel is explicitly a DEF-stacking class. Dodge had a parallel problem: uncapped flat
chance let a high-AGI build occasionally no-sell a whole multi-attack round through variance,
undercutting the 5–8-turn attrition pacing. See [[ideas/def-refreshing-ward]] — "DEF as refreshing ward"
(2026-07-06) and "Consecutive-attack dodge decay" (2026-07-05).
**Alternatives considered:** Keep percentage but hand out less DEF in loot (holds the average
down but not the Sentinel's ceiling — tuning, not structure). A diminishing-returns curve
(soft cap but illegible — already shelved once). For dodge, a hard cap on chance (blunter,
less legible than per-round decay).
**Rationale:** The armor buffer soft-gates structurally instead of by tuning, stays
board-game legible ("50 armor eats 50 damage a round, then I bleed"), and auto-scales across
acts for free (a fixed buffer is huge vs Act 1 numbers, a rounding error vs Act 3 nukes).
It also makes DEF and AGI *complementary* rather than redundant: armor soaks flurries of
small hits and is weak to one big nuke; dodge is strong vs few big hits and decays under
flurries — two near-opposite enemy-design axes. Applied to enemies too for symmetry and to
give the same legible model to the whole combat surface.
**Trade-offs / risks:** If the buffer ever exceeds a round's *total* incoming, chip is fully
nullified for that round — immunity in a new coat. Self-correcting: multi-enemy rounds stack
past the buffer and the act scale-down erodes it, but base armor must stay modest enough to
*blunt* attrition, not erase it. Enemies have no clean per-round hook of their own, so their
refresh is driven externally from `CombatEvent`. Gear/enemy DEF values tuned for the old
percentage will need a balance pass.

---

## Per-hand weapon restriction, offhand moveset, and animated offhand weapons

**Decision:** Weapons declare where they may be equipped via `WeaponData.hand_restriction`
(`Enums.HandRestriction` — `MAINHAND_ONLY` / `OFFHAND_ONLY` / `EITHER`, default `MAINHAND_ONLY`).
The inventory routes equips accordingly: forced slots equip directly; an `EITHER` weapon opens a
**hand-selection interaction** in `InventoryPanel` that mirrors combat targeting — the WEAPON and
OFFHAND slot buttons highlight, `←/→` cycle the choice, `Space`/`Enter` (or clicking a slot)
confirm, `Esc` cancels — and the item is only removed from the bag on confirm, so cancelling never
loses it. A weapon sitting in the offhand uses a new `WeaponData.as_offhand_attacks` moveset if it
defines one, otherwise its normal `attacks`; the override is applied in `_build_hand_actions()`. The
old `WeaponData.offhand_attacks` is **renamed `locked_offhand_attacks`** (it means "what the *locked*
offhand does while THIS two-hander is in the mainhand", not "what this weapon does in the offhand").
Offhand weapons now **animate**: `_setup_equipment` wires an OFFHAND `Weapon` scene node the same way
as the mainhand but flips it (`node.scale.x = -1`) to mirror the mainhand animation, driven by new
`offhand_attack_performed` / `offhand_cast_performed` signals (kept separate so a hand only animates
on its own actions); `_do_attack`/`_do_cast` defer the offhand hit until the offhand weapon's
`hit_landed` / cast-finished, via parallel `_offhand_*` in-flight state. A cosmetic mirrored
`OffhandLayer` was added to the paper doll.
**Date:** 2026-07-03
**Daily:** [[daily/2026-07-03]]
**Context:** A weapon was hard-bound to the mainhand by `EquipmentData.slot`; there was no way to
author an off-hand-capable weapon nor for the player to choose a hand. Scoped in [[ideas/per-hand-weapon-restriction]]
("Per-Hand Weapon Restriction + Offhand Moveset"). This also retired the v1 limitation that only the
mainhand weapon animated (see the dual-action-combat entry below).
**Alternatives considered:**
- *Reuse `EquipmentData.slot` and add an `EITHER` sentinel slot* — rejected; the slot enum maps to
  concrete equipped slots, and a weapon still needs a concrete destination. A separate
  `hand_restriction` keeps slot meaning intact and defaults every existing weapon to `MAINHAND_ONLY`.
- *A modal popup / ConfirmationDialog for hand choice* — rejected in favour of reusing the existing
  keyboard target-selection UX (highlight + `←/→` cycle + confirm/cancel) the user already knows;
  it's consistent and needs no new scene.
- *Remove the item from the bag up-front (as the immediate-equip path does)* — rejected; deferring
  removal to confirm makes cancel/close a no-op that can't lose the item.
- *One shared `attack_performed` signal, filter by hand in the weapon node* — rejected; separate
  `offhand_*` signals mean each weapon node only reacts to its own hand with no per-node filtering.
- *Put `hand_restriction` on `EquipmentData`* — kept on `WeaponData` per the idea; non-weapon
  off-slot items (focuses) still route by their authored `slot`.
**Rationale:** `hand_restriction` on `WeaponData` with a `MAINHAND_ONLY` default is a zero-content-
change migration. The moveset override is a two-line branch in the existing `_build_hand_actions()`.
Mirroring by flipping the root `Weapon` node (not `_sprite`, which `_scale_sprite_to_viewport()`
overwrites) reuses the entire mainhand animation with no new art. The offhand animation path is a
structural parallel of the mainhand path, so `_do_attack`/`_do_cast` stay symmetric.
**Trade-offs / risks:** The offhand path duplicates the mainhand in-flight state and handlers rather
than fully generalizing per-hand — accepted for clarity over a larger refactor. `_rebuild_innate_
spell_names()` still only reads the mainhand weapon, so `get_castable_spells()` name-resolution
ignores an offhand weapon's innate spells (the offhand hand still registers them directly). The
hand-selection `_unhandled_input` coexists with `game.gd`'s; it's safe because game.gd's targeting
block is inactive outside `PLAYER_TURN` and the panel consumes its keys, with a `visibility_changed`
guard that cancels a dangling selection if the panel closes.

## Dual-action combat: per-hand action gating, explicit turn end, focus-granted casting

**Decision:** The player turn splits into two independently-gated action slots — **mainhand** (WEAPON slot) and **offhand** (OFFHAND slot). `Player` replaces its single `_actions` registry with per-hand registries (`_hand_actions[Hand]`, plus `_hand_attacks`/`_hand_spells` source lists) and `_mainhand_used`/`_offhand_used` flags reset by `begin_turn()`. `execute_action(hand, name)` no longer ends the turn: it runs the action and sets `_action_resolving`; `_process` clears that on resolve, marks the hand used, and emits `action_resolved(hand)`. **The turn ends only via the explicit `end_turn()`** (End Turn button or stun `pass_turn()`), which is now the sole place `_tick_statuses()` + `turn_ended` fire. A hand's action set is derived in `_rebuild_hand_actions()` from the item it holds: its `attacks`, plus the prepared repertoire iff the item is a **focus** (`grants_casting`), else a weapon's `innate_spells`; an empty hand falls back to a shared unarmed `Punch`. A two-handed weapon locks the offhand but supplies its supporting action(s) via `offhand_attacks`. Data model: `attacks` + `grants_casting` promoted from `WeaponData` to `EquipmentData`; `offhand_attacks` added to `WeaponData`. v1 keeps offhand actions **non-animating** (only the mainhand WEAPON scene animates).
**Date:** 2026-07-02
**Daily:** [[daily/2026-07-02]]
**Context:** Combat gave one action per turn — `execute_action` set `_turn_pending` and `_process` emitted `turn_ended` the moment it resolved, so turns were one click. [[ideas/dual-action-combat]] ("Dual-Action Combat", 2026-06-30) spec'd two per-hand slots as the player-side counterpart to enemy attack patterns. Spellcasting was an ungated free action independent of equipment; the user asked to fold it into the hand system so it, too, costs a hand.
**Alternatives considered:**
- *One flat action registry keyed by name, with a parallel hand map* — smaller diff, but a mainhand and offhand sharing an action name (two "Punch"es) collide in one dict. Rejected for per-hand registries, which make collisions impossible and hand-gating natural.
- *Auto-end the turn when both hands are spent* — fewer clicks, but the user chose **explicit End Turn always** (turn never auto-ends) for full control and to allow declining a hand.
- *Casting stays a baseline ungated action; a focus only adds a second casting hand* — rejected: the user wanted **no focus, no casting**, unifying casting into the same per-hand economy as attacks.
- *Two-handed weapon forfeits the offhand entirely* — rejected as too costly on action economy; a two-hander instead grants a supporting `offhand_attacks` action.
- *Animate offhand weapons now* — deferred to v2; `_do_attack`/`_do_cast` and the equipment signal wiring hardcode the mainhand WEAPON scene, so a second animating node is a larger change. v1 offhand actions (Brace/cantrip/punch) resolve without animation.
**Rationale:** `_turn_pending` conflated "an action is resolving, block input" with "end the turn on resolve"; splitting it into `_action_resolving` (gating) + explicit `end_turn()` is the enabler for everything else. Deriving each hand's actions from the equipped item in one `_rebuild_hand_actions()` (called on equip/unequip and spell-prep changes, never per turn) keeps a single source of truth and lets `game.gd`/`gui.gd` read per-hand attack/spell lists without re-deriving the focus rule. Casting reuses the existing prepared-repertoire + `get_castable_spells()` machinery; a focus is just `grants_casting = true` (set on `pyre_scepter`/`oak_staff`), so no new item content is needed. SELF Brace and the unarmed punch ride the existing `AttackData`/Effect pipeline with zero new plumbing. Mid-turn hand state never needs saving — `SaveManager.write` only runs after combat.
**Trade-offs / risks:** The CombatHUD scene must define `MainhandActions`/`OffhandActions`/`EndTurnButton` under `ActionMenu`; until then `gui.gd` auto-creates fallback nodes (usable but unstyled). The post-killing-blow window is racy — a mainhand kill can flip the event to RESOLUTION via `await death_finished` while `_process` still emits `action_resolved`, so `_on_player_action_resolved` guards on `PLAYER_TURN` **and** living enemies. Offhand weapons with their own swing animation are unsupported until v2 generalizes `_do_attack`/`_do_cast` per hand. A hand with an innate-spell weapon that isn't a focus still casts that innate spell (weapon channels its own), so "no focus, no casting" applies to the prepared repertoire, not weapon-innate spells.

## Enemy action patterns: data-driven optional move sequence over the `_perform_action` hook

**Decision:** Enemies gain an optional, looping **fixed-sequence** move pattern. New `EnemyMoveData` (name, description, `Target` enum `PLAYER`/`SELF`, `effects: Array[Effect]`, icon, sound) and `EnemyPatternData` (`moves: Array[EnemyMoveData]`) resources. `Enemy` carries an optional `pattern` export and a per-instance `_pattern_index` cursor; `_emit_attack()` is made pattern-aware — with a pattern it emits `move_performed(move)` and advances the cursor (wrapping), otherwise it keeps the legacy `attack(attack_damage)` behavior. Effect resolution lives in `game._on_enemy_move_performed()` (via a `CombatEvent.enemy_move_performed` relay), mirroring `_on_player_attack_hit`: it applies each effect with `source = enemy`, `target = player` (or the enemy itself for `SELF` moves).
**Date:** 2026-07-01
**Daily:** [[daily/2026-07-01]]
**Context:** Every enemy had exactly one hardcoded behavior via `_perform_action()`; there was no turn-to-turn variety and no way for an enemy to apply a status/self-buff/heal — only flat damage. [[ideas/enemy-attack-patterns]] ("Enemy Attack Patterns", 2026-06-30) spec'd a fixed sequence as the enemy-side counterpart to dual-action combat, chosen over weighted/reactive selection because a fixed order makes honest telegraphing trivial (peek the cursor).
**Alternatives considered:**
- *Reuse `AttackData` as the move type* (literal reading of ideas.md) — zero new class, but its `TargetMode` (`SINGLE_ENEMY`/`ALL_ENEMIES`) reads backwards from the enemy's side. Rejected for a dedicated `EnemyMoveData` with enemy-centric `PLAYER`/`SELF` targeting, which also future-proofs enemy authoring.
- *Weighted / reactive (HP- or player-state-driven) selection* — more organic but harder to telegraph honestly; deferred to a later extension per ideas.md.
- *Enemy applies effects directly* — enemies hold no player reference (`take_turn()` takes no args), so the game owns resolution exactly as it does for the player.
**Rationale:** `_emit_attack()` is the single emission seam for **both** the base enemy and animation-gated ones — Skeleton's `.tscn` fires `_emit_attack` from an animation method track at the hit frame — so routing patterns through it means animated enemies need **no code change**; attaching a `pattern` just works. The system is **additive**: subclasses needing code-driven behavior (boss phases, conditional AI) still override `_perform_action()`. `enemy_attack_hit` is re-emitted for damage-bearing player moves so equipment retaliation procs keep firing; damage still flows through `player.take_damage` (DEF mitigation + HP bar) and drives `player_damaged` procs. Registered in the content-editor schema, so patterns are MCP-authorable.

**Follow-up (2026-07-01) — no explicit telegraph HUD.** The pattern system was originally framed around telegraphing the *next* move on the HUD (`peek_next_move()` was added for it). That HUD is **dropped, not deferred**: patterns are meant to be learned through play — the wind-up animation and applied status icons are the telegraph, per the **Combat Feel & Pacing** principle ("the player learns what those states mean through experience"). `peek_next_move()` stays as a code-only accessor (tests/debug); no UI consumes it. Fixed-over-weighted remains the v1 choice on its own merits (simpler, learnable, authorable), independent of the dropped "peek is free" argument.
**Trade-offs / risks:** Enemies expose only `DEFENSE` as a base stat (`_get_base_stat`); STR/CON/etc. evaluate to 0 in `StatExprEval`, so move `DamageEffect` expressions must use literals or `max_health`/`health`, not `strength`-style terms — a real enemy stat block is future work. Per-move `sound` is authorable but not yet wired into animation-gated enemies (they keep their own sfx).

## End-of-act transition: shrine becomes an "EndAct" town that swaps the world map

**Decision:** The terminal `ShrineMapNode` is renamed to `EndActMapNode` (event `ShrineEvent` → `EndActEvent`) and reframed as an end-of-act **town hub**. Reaching it opens a `TownPanel` whose services are **Temple** (the existing `ShrinePanel` ascension) and **Travel Onward**. Travelling onward swaps the live `WorldMap` scene for the node's `next_act_scene` (a new act), or — when that export is empty — wins the run. **Run-ending victory moves off the boss** onto the final act's end-act node.
**Date:** 2026-06-27
**Daily:** [[daily/2026-06-27]]
**Context:** The run is designed as three acts ([[ideas/run-structure-and-act-progression]]) but the code had one hand-authored map and no act machinery; the shrine sat as an unreachable terminal node after the boss, which itself hard-ended the run on `_on_boss_defeated`. We wanted the end of an act to actually load the next act, and the shrine to grow into the planned town hub.
**Alternatives considered:**
- *One big map with act "regions"* — no scene swap, but can't reset node graphs per act and bloats a single hand-authored scene. Rejected.
- *Data-driven `ActData` resource selecting a generic map* — more uniform, but each act's graph (positions/connections/node types) is hand-authored, so a reusable parametric map needs procedural generation we don't have. Deferred.
- *Keep boss = victory* — leaves the town unreachable and blocks multi-act. Rejected; victory now belongs to the end-act node.
**Rationale:** `EndActMapNode` keeps mirroring `ShopMapNode` (bypasses the floor pool) and gains `next_act_scene: PackedScene`. `EndActEvent` stays in `RUNNING` while the town is open and emits `town_requested`; `game.gd` shows `TownPanel`, routes **Temple** to the unchanged `ShrinePanel` (ascension now applied **live** during the visit, not at event resolution, so the player can keep using the town), and **Travel Onward** calls `EndActEvent.on_travel_onward()`. The single return-to-map point `game.gd._on_dungeon_complete()` branches: an `EndActMapNode` routes to `_advance_to_next_act()`, which `GUI.swap_world_map(next_act_scene)` (frees the old map, instantiates the next named `WorldMap` so save paths stay valid, its `_ready()` rebuilds the floor pool + resets) or `_enter_victory()` when there is no next act. Save tracks `current_act` + `active_act_scene_path` so Continue rebuilds the correct act map before `apply_state_dict`; `RunSaveData.VERSION` → 2.
**Trade-offs / risks:** A scene can't `ext_resource` itself, so the placeholder act 2 is a standalone copy (`world_map_act2.tscn`) rather than a literal self-loop; real acts are authored later. The act boss now plays its `on_victory` dialogue but no longer ends the run, which may read oddly until per-act bosses get their own flavor. `swap_world_map` must detach the old node synchronously (not just `queue_free`) or the new map gets auto-renamed and saved paths break. Town services beyond Temple/Travel (shops, blacksmith) are stubbed for later. New `class_name`s need a `godot --import` pass before headless `--check-only` recognizes them.

## Shrine ascension: hand-placed checkpoint + gold tithe (Phase 2)

**Decision:** Patron-saint tier ascension is delivered by a generic `ShrineEvent` reached through a hand-placed `ShrineMapNode`, where the player pays a gold tithe to `ascend_patron()` (replace, never stack) or leaves keeping gold and tier.
**Date:** 2026-06-21
**Daily:** [[daily/2026-06-21]]
**Context:** Phase 1 shipped saints at tier 1 with `ascend_patron()`/`_patron_tier_index` already in place but no in-world trigger. Phase 2 needed the event, the choice UI, and a way for shrines to appear — the original spec ([[ideas/character-creation-layers]]) also wanted an "act" concept the codebase lacks.
**Alternatives considered:**
- *Shrine as a random `FloorEventPool` slot* (like combat/rest) — data-driven placement, but unpredictable and would force an "act"/depth concept to decide which tier/when. Rejected for now.
- *Per-saint authored shrine resources* — custom flavor per saint, but multiplies content authoring; rejected in favor of one generic shrine.
- *Decline grants gold; ascend is free* (journal's original framing) — rejected by the user in favor of "ascend costs gold, decline keeps gold," which reads as a clearer dark-bargain.
**Rationale:** `ShrineMapNode` mirrors `ShopMapNode` — it carries `shrine_scene` + `ascension_cost` and bypasses the floor pool, so no "act" machinery is needed; each shrine just advances one tier via the existing `ascend_patron()`. It is placed as a **between-acts checkpoint** (act-1 end nodes funnel through it into the boss), leaving room to grow into a hub later. `ShrineEvent` reads the active saint at runtime through new public `Player` accessors (`get_patron`/`can_ascend_patron`/`get_active_tier`/`get_next_tier`) and emits `shrine_requested(...)`; `game.gd` shows `ShrinePanel` and routes the choice back via `on_shrine_choice(ascend)`. Replace-not-stack is inherent — `ascend_patron()` does `remove_blessing(current) → add_blessing(next)`. Ascension persists through the existing `_patron_tier_index` save field.
**Trade-offs / risks:** Placement and `ascension_cost` are hand-authored per node (no auto-scaling by act yet). Using placeholder rest-node art. No-patron / final-tier players get a "silent" shrine (Leave only) rather than an alternative reward. New `class_name` scripts require a `godot --import` pass before headless `--check-only` recognizes them.

## Three-layer character identity: Class + Background + Patron Saint

**Date:** 2026-06-07
**Daily:** [[daily/2026-06-07]]
**Context:** Character creation only picked a class. `journal/ideas.md` (2026-05-30) proposed a three-part build identity — Class (*what you can do*), Background (*who you were*), Patron Saint (*what watches over you*) — to deepen build variety and theme. Needed data shapes, player integration, content-editor authoring, and a hand-built creation UI.
**Alternatives considered:**
- *Patron saint as `lineage_id` only* (journal's original) — no wrapper; reconstruct a saint by grouping loose `BlessingData` by string id. Rejected: the selection UI and content editor would have to group by string, and there's no home for the saint's own name/description distinct from tier 1.
- *Background passive as pure explicit fields* — can't express conditional/proc passives. *Background passive as pure `subscriptions`* — economy multipliers (gold reward, shop price) don't fit the signal bus; they're read at specific call sites.
- *3-column single-screen creation UI* — shows all picks at once for synergy reasoning, but the user chose a wizard for a simpler per-step flow.
**Rationale:** `PatronSaintData` is a wrapper resource (`display_name`/`description`/`icon` + `tiers: Array[BlessingData]` of length 3) **and** `BlessingData` gains a `lineage_id: StringName`. The wrapper is one pickable/editable unit and makes ascension trivial (`saint.tiers[n]`); `lineage_id` lets the runtime identify the active saint tier and future-proofs branching evolutions. `BackgroundData` is a hybrid: `stat_modifiers` (signed — drawbacks allowed) + an optional `passive: BlessingData` (reuses the verified `add_blessing`/`get_effective_stat` path) for behavioral effects, plus explicit `starting_gold` and `gold_reward_multiplier`/`shop_buy_multiplier`/`shop_sell_multiplier` floats read by `game.gd._apply_rewards` and `shop_event.gd`. `Player.initialize()` gained optional `background`/`patron` params (default `null` → back-compatible); `_setup_background`/`_setup_patron` mirror `_setup_starting_blessings`. The creation UI is a hand-built 4-step wizard (Class → Background → Saint → Confirm) that resizes with the viewport. Both new resources are pure schema-driven in the content editor (no React code).
**Trade-offs / risks:** A saint's `lineage_id` and each tier's `lineage_id` must be kept in sync (the create-saint skill does this). Background has two stat-shift surfaces (its own `stat_modifiers` + its passive's). Saint *tiers* live in `resources/patron_saints/tiers/` and background passives in `resources/backgrounds/passives/`, kept out of the general blessing pool so unique saint shapes can't leak into random rewards. **Shrine ascension is deferred to Phase 2** — it needs a new event type and an "act" concept the codebase lacks; Phase 1 ships saints at tier 1 (fully playable) with `_patron_tier_index` and `ascend_patron()` already in place. The sample Saint of Ambush expresses its tiers via `stat_modifiers` + a tier-3 heal-on-kill subscription; the "first attack deals Nx damage" proc described in ideas.md needs a new effect type (future work).

## Authored dungeon floors with polymorphic slot system

**Date:** 2026-05-23
**Daily:** [[daily/2026-05-23]]
**Context:** `DungeonMapNode.generate_event_configs()` previously picked events randomly from per-type JSON directories — no authoring control over floor shape, pacing, or the sequence of event types. The miniboss was also appended inside the depth loop, producing N−1 minibosses per dungeon (latent bug).
**Alternatives considered:** Three separate floor types (ScriptedFloor, WeightedFloor, HybridFloor) — rejected because you can't mix modes per-slot; would also produce three sidebar entries where one suffices. GDScript subclass hierarchy for slot types — attempted but abandoned because Godot's headless `--script` mode doesn't propagate `class_name` registrations between scripts compiled on-demand, causing cascading "base class not found" errors.
**Rationale:** Single `FloorSlot` resource with a `type` enum (FIXED / RANDOM_TYPE / WEIGHTED) and all fields on the same class. Each slot in a `DungeonFloorData` array can independently be any of the three modes. Assignment to world-map nodes at run-start via `FloorEventPool` + seeded `RandomNumberGenerator` on `WorldMap`; DungeonMapNode accepts a specific `floor` override OR `floor_tags` for filtered random selection. Resolves to a cached `_resolved_event_configs` array once per world-map load, then `generate_event_configs()` just returns it — no changes to `game.gd`'s sequencing machinery.
**Trade-offs / risks:** All three slot modes' fields are always visible in the editor (slightly noisy); FIXED-only used fields are wasted space. GDScript headless compilation ordering constrains how resource scripts may reference each other — custom classes used as typed Array elements must be in the same script as the array or use untyped `Array` + annotations.json entry. BossMapNode is untouched — it still loads a single event directly; can be migrated to a 1-slot floor later.

---

## Events exposed in content editor via .tres-wraps-JSON wrappers

**Date:** 2026-05-22
**Daily:** [[daily/2026-05-22]]
**Context:** Event JSON files (`resources/events/*/`) were invisible in the content editor. They can't go through the schema-driven ResourceForm because their data structure is in JSON, not `.tres`. Need a path into the sidebar without rewriting the event runtime (which loads by JSON path strings from `DungeonMapNode` and friends).
**Alternatives considered:**
- Convert event JSON to pure `.tres` Resource subclasses — type-safe but requires runtime changes everywhere JSON paths are used (`DungeonMapNode.combat_json_dir`, etc.) and more Godot-side boilerplate.
- Expose events via a separate "Events" tab with direct JSON listing from the sidecar — simpler but doesn't get the schema-driven sidebar, `.tres` watcher, or where-used index.
**Rationale:** Same pattern already validated by DialogueData v2: a thin `.tres` wrapper holds `display_name` + `event_path`. Runtime stays unchanged (DungeonMapNode reads the JSON path directly). The wrapper integrates with the schema-driven sidebar and opens a custom EventEditor view per type.
**Trade-offs / risks:** The `.tres` and `.json` files can drift if someone edits the JSON externally — accepted. Display name on the wrapper is purely editor-side metadata, not visible in-game.

---

## Dialogue storage: DialogueData .tres wraps JSON tree

**Date:** 2026-05-22
**Daily:** [[daily/2026-05-22]]
**Context:** Building a content editor graph view for dialogues. Dialogues are JSON files; the content editor is schema-driven from `.tres` Resources. Needed a way to list dialogues in the sidebar, persist graph layout (node x/y positions), and integrate with the schema system — without rewriting the entire dialogue runtime.
**Alternatives considered:**
1. Convert dialogues fully to Godot Resources (`DialogueData` with `Array[DialogueNode]`). Full schema integration. But Godot Resources aren't great for sparse graphs with string-id cross-references; would need separate files per node or complex inline structures.
2. Pure JSON editor — a standalone editor route that reads/writes JSON directly, no .tres involvement. Simpler but doesn't integrate with the sidebar type list, `+` creation button, or where-used index.
3. **Hybrid (chosen):** `DialogueData.tres` holds metadata (`display_name`, `dialogue_path`, `node_positions_json`) and points at the existing JSON. The schema system sees a normal resource class; the content editor detects `DialogueData` and swaps in a custom React Flow graph view instead of the generic form.
**Rationale:** Hybrid keeps the runtime untouched — `DialoguePanel` still parses JSON directly, and `DialogueEvent` falls back to `data["dialogue"]` if `dialogue_data` is null. Graph layout persists on the .tres without touching the dialogue contract. The custom editor view is the only frontend special-case; all sidebar/creation/listing machinery works for free.
**Trade-offs / risks:** `DialogueData` is the only content type with a custom editor view (others use the generic `ResourceForm`). A new contributor might not expect this. The mapping is in `App.tsx` and is obvious. Dialogue JSON is also the only content type not round-tripped through `io_read/io_write.gd` — the sidecar reads/writes it directly with `fs.readFileSync/writeFileSync`.

---

## Flat-percentage defense and dodge formulas

**Date:** 2026-05-19
**Daily:** [[daily/2026-05-19]]

> **Superseded (2026-07-07)** by "DEF is a refreshing per-round armor buffer; AGI dodge
> decays within a round" (above). DEF is no longer a percentage — it's an armor buffer that
> absorbs damage before HP and refreshes each round; dodge chance now decays per successful
> dodge within a round. The legibility goal below still holds; only the formulas changed.

**Decision:** `DEF` and `AGI` are both direct percentages. `DEF = 50` means 50% damage resistance. `AGI = 15` means 15% dodge chance. No scaling constants.

```
_apply_defense: damage * (1.0 - clamp(DEF / 100.0, 0, 1))  — floor 1 (player), 0 (enemy)
_roll_dodge:    randf() < clamp(AGI / 100.0, 0, 1)
```

**Context:** The prior formula (`DEF / (DEF + 100)`) was a diminishing-returns curve — not legible without a graph. Players couldn't reason about what their DEF stat actually meant. The dodge formula used a separate `DODGE_AGI_FACTOR` constant for the same reason. See [[ideas-archive.md]] — "Defense & Dodge Formula" (2026-05-15).

**Alternatives considered:** Diminishing-returns formula (`DEF / (DEF + SCALING)`) — already implemented and shelved. Offers a natural soft-cap without explicit clamping, but the relationship between stat and outcome is opaque.

**Rationale:** The player should be able to look at their stat sheet and immediately know their effective protection: "50 DEF, I take half damage. 15 AGI, I dodge 15% of attacks." The formula stays constant across the run — tier progression is expressed through gear values, not formula complexity.

**Trade-offs / risks:** Linear scaling means high-DEF builds can reach immunity at DEF 100. Gear values calibrated for the old formula will need retuning — default 50 DEF is now 50% resistance vs ~33% under the old formula.

---

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
   - `duration: int` — turns; `-1` = never ticks down (does **not** by itself imply run-permanence — see `persistence`)
   - `stat_modifiers: Dictionary` — optional flat stat layer while active
   - `prevents_action: bool` — combatant skips its turn
   - `on_apply: Effect`, `on_tick: Effect`, `on_expire: Effect` — any may be null
   - `stack_policy: enum { REFRESH, STACK, MAX_DURATION }` — default `REFRESH`
   - `persistence: enum { COMBAT, PERSISTENT }` — default `COMBAT`; whether the status survives a fight (added 2026-07-08, see "Combat-inflicted statuses clear at combat end" above)
   - `suppresses_armor_refresh: bool` — default `false`; while any active status has this set, the bearer's `refresh_armor()` is skipped (Shatter). Added 2026-07-09, see "Elemental & martial status-verb systems" above
   - `subscriptions: Dictionary` — signal-name → Effect, wired to the lifecycle bus on apply and disconnected on removal/clear, mirroring `BlessingData.subscriptions`. For *reactive* statuses; per-turn ticks stay on `on_tick`. Added 2026-07-09

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
