# Player-Facing Information & Combat Legibility (tooltips, descriptions, feedback)

**Added:** 2026-06-21
**Summary:** Surface what attacks/weapons/statuses/procs actually do — tooltips, gear descriptions, proc/self-cost visibility, and damage-source feedback.

## Notes

There's currently no way to learn what an attack does without already knowing it from the code — picking "Assassinate" off the action list doesn't say what it does or who it targets. Related UI surfaces, all one underlying gap (attacks/weapons/statuses need player-facing descriptions, not just internal effect data):
1. *In-combat action tooltips* — on action buttons, showing effect and target type before committing to a turn.
2. *Weapon/equipment descriptions* — in the inventory/equip screen, listing the attacks a weapon grants **and its passive procs / on-equip effects / self-costs**, so gear choices are informed by actual combat behavior, not just stat deltas.
3. *Passive-proc visibility* — the motivating case (2026-07-08): the Assassin's starting **Vorpal Blade** deals `max(5, 25 - agility*0.4)` recoil self-damage on every hit (`player_attack_hit` proc, `apply_to_owner`), which reads as unexplained "5 armor damage when I attack." The player has no surface anywhere — not the weapon screen, not combat — telling them the weapon bites back. Procs, on-equip effects, and self-damage are entirely invisible today.
4. *In-combat damage-source feedback* — the combat log/HUD should name **where** damage came from (recoil, poison tick, enemy X's move), not just show numbers. `game.gd` already logs "Your armor absorbs N damage" but not the cause; statuses tick silently. This is also the natural payoff surface for the status work (poison/bleed/burn ticks should announce themselves).

**Priority:** flagged as the **next thing to tackle after the status-effect groundwork** (user, 2026-07-08). The recoil confusion made it concrete — the game hides too much of its own math from the player, which fights the "readable enemies/state, surprise through mechanics not hidden numbers" goal in [[ideas/combat-feel-and-pacing]].

## Shipped

Design work started, no player-facing surfaces yet. A **"Combat UI Information Inventory (design-sketch checklist)"** — 10 concern-areas enumerating the legibility gaps this pass targets (elemental/martial statuses, procs, self-costs, damage sources all tagged *invisible today*) — was drafted into [[detailed/gui-design.md]] on 2026-07-09 (see [[daily/2026-07-09]]).

## Remaining

Sketch a layout against the inventory and pick the surfacing approach, then build the actual surfaces: in-combat action tooltips, weapon/equipment descriptions (incl. procs / on-equip / self-costs), passive-proc visibility, and named damage-source feedback in the combat log.
