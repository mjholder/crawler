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
