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
