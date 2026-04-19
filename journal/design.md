# Design Decisions

A log of significant design and architectural decisions, and the reasoning behind them.
Cross-reference daily logs with `See design.md — YYYY-MM-DD` when a decision is made.

---

## Template entry

**Decision:** [What was decided]
**Date:** YYYY-MM-DD
**Context:** [What problem or question prompted this]
**Alternatives considered:** [What else was on the table]
**Rationale:** [Why this option]
**Trade-offs / risks:** [What this choice costs or risks]

---

<!-- Add entries below, newest first -->

## Rewards follow player choice, not event identity

**Decision:** `DialogueEvent` and `SkillCheckEvent` no longer declare rewards at the event level. Dialogue rewards live on **terminal nodes** (empty `choices`) of the dialogue tree as an optional `rewards: { experience, gold }` dict; `DialoguePanel` now emits `dialogue_complete(terminal_node_id: String)`, and `DialogueEvent.on_dialogue_complete(terminal_node_id)` populates the inherited `rewards` field from that node before `_advance_phase()`. SkillCheckEvent replaces its flat `rewards` with `rewards_on_success` / `rewards_on_failure`; `_on_resolution()` picks the right dict based on `_success` at its first line, so rewards are set even when no result dialogue fires. No event-level fallback — paths without declared rewards grant nothing. `game._apply_rewards()` is untouched; it still reads `current_event.rewards` at `_on_event_complete()`.
**Date:** 2026-04-19
**Context:** Every branch through a dialogue tree, and every outcome of a skill check, paid out the same flat reward. The branching itself was meaningful for flavor (flags, consequences) but not for progression, which undermines the point of giving the player a choice.
**Alternatives considered:** (a) Extend the existing `DialogueConsequences` dispatcher with a `give_experience` action and fire rewards via node `consequence` blocks — rejected because nodes currently support only one consequence, and authors frequently want to pair a flag with a reward at the same path end. (b) Keep an event-level default `rewards` as a fallback when no terminal node specifies one — rejected to avoid two sources of truth; every rewarding path must declare itself. (c) Accumulate rewards along the path (sum of every visited node) — rejected as too easy to author accidentally imbalanced outcomes; only the chosen path-end pays.
**Rationale:** Terminal-node `rewards` reuses the event's inherited `rewards: Dictionary` field, so `game._apply_rewards()` and the event phase machine need no changes — the only new information is "which terminal node did the player stop on," and `DialoguePanel` already tracks `_current_node_id`. For SkillCheckEvent, setting `rewards` at the top of `_on_resolution()` keeps reward selection co-located with the rest of the per-outcome branching (which dialogue path to show) and handles the "no result dialogue" case without a second code path. Skill-check flavor dialogues intentionally ignore any terminal-node `rewards` — the skill check owns its reward domain.
**Trade-offs / risks:** Signal signature change on `dialogue_complete` ripples through `dialogue_panel.gd`, `gui.gd`, and `game.gd` — SkillCheckEvent and CombatEvent branches now receive a `terminal_node_id` they don't consume (harmless but asymmetric). Authors must remember to add `rewards` explicitly; forgetting yields a silent zero-reward path rather than a default. Mid-tree `consequence` side effects (e.g. `give_gold`) still fire and stack with terminal-node rewards, which is intentional but must be accounted for when tuning economy.

---

## Game-end system: VICTORY state + BossEvent intercepts at the event layer

**Decision:** Game over and victory are two distinct terminal flows. **Game over** is triggered by `player.died` in any event; `game.gd._on_player_died()` sets `state = GAME_OVER`, calls a new shared helper `_teardown_current_event()` to clean up whatever event was active, then calls `gui.show_game_over()`. **Victory** is triggered by an explicit new event subclass `BossEvent extends CombatEvent`, placed on a new `NodeType.BOSS` world-map node. BossEvent overrides `_advance_phase()` so that when all enemies die it emits a dedicated `boss_defeated` signal instead of transitioning to RESOLUTION/COMPLETE; `event_complete` is intentionally never emitted on boss victory. `game.gd._on_boss_defeated()` sets `state = VICTORY`, applies rewards off the event, tears it down, nulls all dungeon-progress state (skipping `_on_dungeon_complete` entirely), shows the level-up panel if points are pending (so the player can allocate the final earned points), then shows the victory panel. Both GameOverPanel and VictoryPanel emit a unified `main_menu_requested` intent that `gui.gd` re-emits as the existing `quit_to_main_requested`, routing to `game.quit_to_main()`. A shared `_teardown_current_event()` extracted from `_on_event_complete()` is called by the normal completion path, the death path, and the victory path so cleanup stays symmetric across all three terminations.
**Date:** 2026-04-17
**Context:** The game had no terminal states. `player.died` set `state = GAME_OVER` but no UI responded and gameplay hung. Finishing every world-map node just looped back to the map. Two things were needed: a loss flow, and an explicit win flow. The user specifically did not want the win to be detected programmatically ("is this the last event?") — it should be a deliberate design decision per-map, marked by an explicit node type and event type.
**Alternatives considered:** (a) Flag on CombatEvent data (`is_final_boss: bool`) reusing the existing combat scene — rejected for mixing terminal-flow concerns inside CombatEvent and making the win path implicit in JSON. (b) Standalone `BossEvent extends Event` that reimplements combat — rejected for duplicating enemy-spawn and turn-resolution logic. (c) Intercepting victory at `_finish_event()` with a `state == VICTORY` guard — rejected because it smears terminal logic across two functions and still routes through `_on_dungeon_complete → world_map_on_dungeon_complete`, which incorrectly marks the node COMPLETED and re-shows the map. (d) Flag on WorldMapNode (`is_boss_node: bool`) — rejected for muddying the `node_type` contract with a parallel boolean.
**Rationale:** BossEvent as a `CombatEvent` subclass is the cheapest possible structural change — all enemy, HUD, music, and per-event signal wiring is inherited for free via the existing `event is CombatEvent` branch in `start_event()`. Only one extra connection is needed (`boss_defeated` on an `event is BossEvent` check). A dedicated terminal signal at the event layer (rather than overloading `event_complete`) keeps victory handling in one dedicated function, skips the reward-→-level-up-→-next-event pipeline that doesn't apply when the run is over, and avoids the wrong-semantics problem of `_on_dungeon_complete` re-showing the map. A new `NodeType.BOSS` mirrors the existing SHOP/REST handling in `world_map_node.gd` exactly — `_build_boss_config()` alongside `_build_rest_config()` and `_build_shop_config()`. Unified `main_menu_requested` → `quit_to_main_requested` preserves the one-intent-one-destination principle; both panels ask game.gd to do the same thing, so they feed the same signal. The shared `_teardown_current_event()` helper is the load-bearing refactor — it fixes the "GAME_OVER does nothing" bug, makes the death flow symmetric with normal completion, and gives victory a clean path to reuse existing disconnect logic without duplication.
**Trade-offs / risks:** BossEvent deliberately does not emit `event_complete` on win, which is a minor reinterpretation of the event contract — previously, every event emitted `event_complete` when done. The contract is now "events emit `event_complete` OR a dedicated terminal signal when done." Documented in `event-system.md § BossEvent`. Multiple BOSS nodes on one map are mechanically allowed but any `boss_defeated` ends the run; if future design wants a mid-run boss-tier encounter that doesn't terminate, that will require a distinct subclass. `quit_to_main()` currently does not reset player state (HP/XP/gold/inventory) — relevant when starting a new run after death/victory. Not resolved here; flagged in the plan as an implementation-time check (`_on_character_created` may already do enough on a fresh character create).

---

## Shop transactions route through game.gd, not the panel or the event

**Decision:** For the upcoming `ShopEvent` / `ShopPanel`, all validation and state mutation for buy/sell transactions live in `game.gd`. `ShopPanel` emits intent signals (`buy_requested`, `sell_requested`, `leave_requested`) with only an `EquipmentData` payload; `GUI` re-emits them; `game.gd` reads `player.gold`, validates price and bag capacity, calls `player.spend_gold` / `player.add_gold`, mutates the bag via `inventory.add_to_bag` / `remove_from_bag`, and tells `ShopEvent` what happened via `on_buy(item)` / `on_sell(item)` so it can update its `_stock`. `ShopPanel` holds no references to `Player`, `Inventory`, or `ShopEvent`.
**Date:** 2026-04-14
**Context:** Designing the shop node type. The natural shortcut was to pass `player` and `shop_event` into `shop_panel.setup()` so the panel could compute prices, check the bag, and mutate state directly. This would have violated the "Passive GUI" rule (2026-03-12) and the "`game.gd` is the sole class that holds a `var player` reference" rule (2026-03-01).
**Alternatives considered:** (a) Panel holds direct refs to player/event and performs transactions; (b) `ShopEvent` holds the player reference and `game.gd` just routes signals; (c) a transaction service class.
**Rationale:** This matches the established `SkillCheckEvent` pattern — "`game.gd` is the only place `player.get_effective_stat()` is called… the event never holds a player reference." Keeping all policy (enough gold? bag full?) in `game.gd` means the shop behaves exactly like every other event: event requests a UI, UI emits intents, game.gd decides, game.gd tells the event the result. No new architectural patterns.
**Trade-offs / risks:** `game.gd` grows another handler set (`_on_gui_shop_buy_requested`, etc.) and has to explicitly pass state through on every refresh (stock, bag, gold, `bag_full: bool`) rather than the panel reading from live references. Accepted — explicit data flow is easier to trace than implicit reference-based reactivity, and the pattern is already established for every other panel.

---

## UI Architecture — Passive GUI with Intent-Based API

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

**Decision:** All player POV sprites (weapons, hands) are exported at 480x270 to match the internal pixel art reference resolution.
**Date:** 2026-03-08
**Context:** The game runs at 1920x1080 or higher, but we needed a fixed export size for POV sprites so that Godot's upscaling preserves the retro pixel art aesthetic. Tested 480x270 in-engine and confirmed it looks correct.
**Alternatives considered:** No formal alternatives evaluated — 480x270 was tested directly and accepted on visual merit.
**Rationale:** Exporting at 480x270 captures the sprite at the exact scale it should appear from the player's POV. Upscaling from this resolution to the display resolution produces the desired pixel art look without additional filtering or engine tricks.
**Trade-offs / risks:** If the reference resolution ever changes, all POV sprites need to be re-exported. Low risk in practice because assets are rendered from 3D models, so re-rendering at a new size is straightforward.

---

## Signal-based attacks and player reference isolation

**Decision:** Player and Enemy both emit `attacked(damage: float)` signals when they act rather than calling `take_damage()` directly on a target reference. `game.gd` is the sole class that holds a `var player` reference. Events expose `receive_player_attack(damage)` for routing player damage to the appropriate enemy, and emit `player_attacked(damage)` for routing enemy damage back to `game.gd`. `Event.start()` takes no arguments — events no longer receive a player reference at all.
**Date:** 2026-03-01
**Context:** The original design passed target nodes across ownership boundaries: `enemy._perform_action(target: Node)` called `target.take_damage()` directly via duck typing, `player._do_attack(target: Node)` did the same, and `event.start(player: Player)` spread the player reference into the event layer. This created tight coupling and violated the principle that `game.gd` should be the sole owner of the player.
**Alternatives considered:** Typed `Combatant` base class with a shared `deal_damage(target: Combatant)` method; keeping direct calls but enforcing typed parameters; a central event bus.
**Rationale:** Godot best practices strongly favour loose coupling via signals. Neither combatant needs to know what it's hitting — the event layer owns target selection for player attacks, and `game.gd` owns damage application to the player. This makes both Player and Enemy independently testable and keeps all player-touching code in one place.
**Trade-offs / risks:** Adding a new action type that needs to target something specific (e.g. a heal targeting a specific ally) requires extending the signal/routing pattern rather than passing a direct reference. `execute_action()` no longer accepts a target parameter, so action callables must pull context from signals or event state rather than receiving it directly.

---

## Visual style — pixel art rendered from 3D models

**Decision:** Sprites are produced by rendering 3D models into pixel art frames rather than hand-drawn pixel art or ASCII art. Each enemy and character is modelled, rigged, posed, and exported as a spritesheet per state (idle, attack, hurt, death).
**Date:** 2026-03-01
**Context:** Needed to commit to a visual style before building the UI and enemy display systems. ASCII art was the implicit placeholder; pixel art from 3D renders was explored as an alternative.
**Alternatives considered:** ASCII art (terminal-style); hand-drawn pixel art; full 3D in-engine rendering.
**Rationale:** Pixel art from 3D renders gives consistent proportions and lighting across all characters without requiring hand-drawing skill for every asset. The skeleton enemy was the first asset produced under this approach and confirmed the style is achievable and looks good. It also sets a replicable pipeline for future enemies.
**Trade-offs / risks:** Asset production requires a 3D modelling and rigging step before any in-game sprite exists. Pipeline (model → rig → pose → render → import) needs to stay consistent across all characters or visual coherence breaks. Sprite resolution and palette should be standardised early.

## Scoped state ownership — enemies belong to events, player belongs to game.gd

**Decision:** The player reference lives on game.gd and persists across all events. Enemy references live on the event that spawned them and are gone when the event ends. Events receive the player as an argument on `start(player)` for the duration of the encounter.
**Date:** 2026-02-22
**Context:** game.gd previously held both player and enemy references. Enemies are transient (encounter-scoped); centralising them in game.gd means teardown has to happen there too, and game.gd accumulates knowledge it shouldn't need.
**Alternatives considered:** All participants owned by game.gd; all participants owned by the event (including player).
**Rationale:** Ownership follows logical lifetime. The player persists across a full run — save state, stats, inventory all live there. Enemies exist for one encounter. Keeping enemies on the event means signal wiring, wave tracking, and teardown are all self-contained; when the event is freed, all of that goes with it cleanly. game.gd stays thin.
**Trade-offs / risks:** Events need to communicate outcomes back to game.gd (loot gained, XP earned, player health after combat) through the `event_complete` signal payload or a result object rather than game.gd reading state directly. That contract needs to be defined consistently across event types.

---

## Event state machine with virtual phase hooks

**Decision:** Events are implemented as a base `Event` class with a fixed phase enum (`SETUP → RUNNING → RESOLUTION → COMPLETE`) and virtual hooks (`_on_setup()`, `_on_running()`, `_on_resolution()`) that subclasses override. The base class owns phase transition logic and emits `event_complete` when done; game.gd waits for that signal without ever inspecting phase state directly.
**Date:** 2026-02-22
**Context:** Event types need to be independently complex (e.g. a combat event with pre-fight dialogue, multiple enemy waves, and a post-fight loot phase) without that complexity leaking into game.gd or requiring architectural changes later.
**Alternatives considered:** Base class with a single virtual `load(game)` method; signal-driven event bus; flat match statement in game.gd per event type.
**Rationale:** A fixed phase scaffold on the base class means all events speak the same language to game.gd, while subclasses have full freedom inside each phase hook. A `CombatEvent` can loop back through `RUNNING` for additional waves internally — game.gd never knows or cares. New event types are a new file with no changes to the host.
**Trade-offs / risks:** The fixed phase order may not fit every event type naturally. Phases that don't apply to a subclass just get empty overrides, which is fine, but if events need radically different flow the base enum may need revisiting.

---

## Explicit participant setup over scene-tree auto-collection

**Decision:** Player is set via `set_player()` and enemies are loaded via `load_combat_event()` rather than auto-discovered from scene children in `_ready()`.
**Date:** 2026-02-22
**Context:** Auto-collecting from the scene tree works for a static test scene but breaks down when participants come from save data, procedural dungeon generation, or event-driven encounter loading.
**Alternatives considered:** `@onready` node path references; scanning `get_children()` at startup.
**Rationale:** `set_player()` can be called at startup or after loading a save with no code change. Event classes call `load_*_event()` to hand off their participant data when an encounter begins — game.gd stays passive and reacts rather than pulling. Signal connections happen at the point participants are registered, keeping setup and teardown co-located.
**Trade-offs / risks:** `_ready()` no longer auto-starts anything; callers must explicitly call `set_player` and a `load_*_event` function before the game loop runs. Need to guard against calling turn-flow functions before a player is set.

---

## Player action registry

**Decision:** Player actions are stored as a `Dictionary` of `Callable`s and executed via `execute_action(name, target)`.
**Date:** 2026-02-22
**Context:** Player turns need to support multiple actions (attack, spells, items, etc.) without game.gd needing to know about specific methods, and without a growing match/switch block.
**Alternatives considered:** Match statement in game.gd dispatching to named methods; abstract virtual methods per action type; direct method calls from UI.
**Rationale:** A dictionary of callables means new actions are one `register_action()` call — no changes needed in game.gd or the Player class itself. `execute_action` is the single point that emits `turn_ended`, so the turn signal fires exactly once per action regardless of what the action does.
**Trade-offs / risks:** Action names are plain strings — no compile-time safety. Typos will silently do nothing (the `has()` check guards against crashes). Consider defining action name constants if the list grows large.

---

## Enemy AI via override hook

**Decision:** Enemy decision-making lives entirely in `_perform_action(target)`, which subclasses override to implement different behaviours.
**Date:** 2026-02-22
**Context:** Different enemy types need different AI without the game manager needing to know the difference between them.
**Alternatives considered:** Strategy pattern (inject an AI object); match on enemy type in game.gd; signal-based action requests.
**Rationale:** GDScript inheritance and virtual method override is the simplest path. game.gd calls `enemy.take_turn(player)` uniformly for every enemy — each type handles its own logic internally. A goblin, a boss, and a passive creature are all just `Enemy` nodes to the game manager.
**Trade-offs / risks:** Deep inheritance trees get hard to manage. If behaviours need to be composed (e.g. an enemy that sometimes charges, sometimes heals), a strategy/component approach may be needed later.

## Signal-based UI/logic separation

**Decision:** Player and Enemy emit signals for game events; UI and game manager connect to those signals externally.
**Date:** 2026-02-22
**Context:** Needed an architecture for keeping visual feedback (health bars, combat log) decoupled from game logic (turn order, win/lose conditions).
**Alternatives considered:** Having Player/Enemy directly call UI methods; using a central event bus.
**Rationale:** Signals are Godot's native observer pattern. Emitters don't need references to the UI or game manager — they just fire and let receivers react. All connections live in one place (game.gd), making data flow easy to trace.
**Trade-offs / risks:** Signal connections need to be managed carefully to avoid dangling connections when nodes are freed (use `connect` with `CONNECT_ONE_SHOT` or disconnect on death where needed).
