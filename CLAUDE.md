# Crawler — Claude Context

## Project

Turn-based roguelike dungeon crawler. **Godot 4.6**, GDScript only. Early prototype — core turn loop exists, most systems are stubs or not yet built.

## Directory Layout

```
scripts/   # GDScript source
scenes/    # Godot .tscn files
assets/    # Audio, sprites
journal/   # Developer docs (design decisions, ideas, daily logs)
```

## Key Files

| File | Role |
|---|---|
| `scripts/game.gd` | Turn state machine; orchestrates turn flow only |
| `scripts/player.gd` | Player character; action registry pattern |
| `scripts/enemy.gd` | Enemy base class; AI via `_perform_action()` hook |
| `journal/design.md` | Architectural decisions with rationale — read before changing structure |
| `journal/ideas.md` | Future systems backlog |
| `journal/daily/` | Session logs |

## Established Architecture

These decisions are documented in `journal/design.md`. Do not change them without discussion.

**Turn flow** — `game.gd` owns the state machine (`NO_TURN → PLAYER_TURN → ENEMY_TURN → GAME_OVER / ENEMY_CLEARED`). It stays thin: it knows turn order, not event internals.

**Scoped ownership** — The player lives on `game.gd` and persists across the run. Enemies are owned by the event that spawns them and freed when the event ends.

**Explicit setup** — No scene-tree auto-discovery. `game.gd` receives participants via `set_player()` and `load_*_event()`. This keeps save loading and procedural generation viable.

**Player action registry** — Actions are stored as `Dictionary[String, Callable]`. New actions use `register_action(name, callable)`. `execute_action()` is the single point that emits `turn_ended` — do not emit it elsewhere.

**Enemy AI hook** — Subclasses override `_perform_action(target: Node)`. `game.gd` calls `enemy.take_turn(player)` uniformly for all enemy types. Don't add enemy type checks in game.gd.

**Event state machine (planned)** — Base `Event` class with phases `SETUP → RUNNING → RESOLUTION → COMPLETE` and virtual hooks `_on_setup()`, `_on_running()`, `_on_resolution()`. Events emit `event_complete` when done; game.gd waits for that signal without inspecting internal phase state.

**Signal-based UI separation** — Player and Enemy emit signals; UI connects externally. Emitters do not reference the UI.

## Conventions

- GDScript 4.x typed syntax — use type hints on function parameters and return values
- Signals declared at the top of the file, before stats
- Section comments use `# --- Section Name ---`
- Extension hooks on Enemy (`_on_ready`, `_on_damaged`, `_on_death`) use a leading underscore and do nothing in the base class
- `@export` vars are placeholder stats for now; they will be replaced by a proper stat system (STR/CON/AGI/SPI/LCK)
- Prefer guard clauses over nested conditionals

## Journal

Log significant decisions in `journal/design.md` using the template at the top of that file. Log daily work in `journal/daily/YYYY-MM-DD.md` using `journal/daily/TEMPLATE.md`.

## What's Not Built Yet

- `Event` base class and concrete implementations (`CombatEvent`, `SkillCheckEvent`, `LootEvent`, `RoleplaysEvent`)
- UI layer (health bars, combat log, action menus)
- Full stat system — currently flat `@export` floats on Player and Enemy
- Equipment and inventory
- Procedural dungeon/floor generation
- Loot and XP systems
