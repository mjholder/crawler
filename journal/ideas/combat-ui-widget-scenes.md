# Reusable combat-UI widget scenes

**Added:** 2026-07-11
**Summary:** Extract the code-built combat-UI widgets (attack buttons, consumable belt slots, status icons) into reusable `.tscn` scenes — each with its own small script — following the `health_bar.tscn` pattern.

## Notes

Right now the combat UI mixes three different patterns for "reusable" widgets, which
makes restyling inconsistent — some pieces are editable as scenes, others only in code.

Existing patterns in the codebase:
- **PackedScene + `instantiate()`** — `health_bar.tscn`, instanced via
  `@export var _health_bar_scene: PackedScene` in `gui.gd`. The clean model to follow.
- **Hidden template node + `.duplicate()`** — the consumable belt keeps a hidden
  `ConsumableButton` in `game.tscn` and duplicates it (`consumable_belt_ui.gd:52`).
  Works, but the widget definition is buried in `game.tscn`.
- **`Node.new()` in code** — attack buttons and status icons are built entirely in
  GDScript, no scene at all.

### Audit

| Element | Current form | Reusable scene? | Action |
|---|---|---|---|
| Enemy health/armor bar | `health_bar.tscn` + instantiate | ✅ done | model to follow |
| Attack/action buttons | `Button.new()` inline (`gui.gd` `_add_action_button`) | ❌ code-built | **extract → `action_button.tscn`** |
| Consumable belt slot | hidden template Button in `game.tscn`, `.duplicate()`d | ⚠️ half-way | **extract → `consumable_slot.tscn`** |
| Player status icon | `TextureRect.new()` + stack `Label` inline (`gui.gd` `_make_status_icon`) | ❌ code-built | **extract → `status_icon.tscn`** |
| Enemy status label | bare `Label.new()` on the health bar (`gui.gd` `add_enemy_status_label`) | ❌ code-built | optional — fold into `health_bar.tscn` or a small enemy-status widget |
| End Turn button | static node in `game.tscn` | single instance | leave as-is (unless it should share the attack-button style) |
| Combat log | static `RichTextLabel` | single instance | leave as-is |
| Player resource bars (HP/armor/mana/XP) | static nodes in `game.tscn` | single instance, shared visual pattern | optional `resource_bar.tscn` to dedupe styling; low priority |

### The real win: scene **+ script**, not just scene

The biggest payoff is moving per-widget *behavior* out of `gui.gd` (700+ lines). The
attack button currently owns a lot of logic that lives in `gui.gd`: text formatting
(`"%s (%d)"`), `hand`/`action`/`cost` metadata, disabled gating, and the targeting
highlight (`modulate = Color(1.4,1.4,0.6)`). A small script on the extracted scene can
own its own appearance + state, so `gui.gd` just instances and feeds data. Same for the
status icon (icon + stack badge + tooltip builder).

### Direction

Standardize all three on the `health_bar.tscn` pattern (a real `.tscn` instanced via
`@export PackedScene` / `preload`) rather than the template-duplicate approach — one
consistent way to build reusable widgets, and it un-buries the consumable button from
`game.tscn`. Worth doing as one coherent pass since it touches `gui.gd`,
`consumable_belt_ui.gd`, and `game.tscn` together.

Related legibility work: [[ideas/player-facing-legibility]] (tooltips / proc visibility
could ride on these widget scripts).

## Shipped
<nothing yet>

## Remaining
- `action_button.tscn` (+ script) — replace `_add_action_button` / `_populate_hand_group` construction
- `consumable_slot.tscn` (+ script) — replace the hidden `ConsumableButton` template + `.duplicate()` in `consumable_belt_ui.gd`
- `status_icon.tscn` (+ script) — replace `_make_status_icon`
- (optional) enemy status widget, `resource_bar.tscn`
