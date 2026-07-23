# Player-Facing Information & Combat Legibility (tooltips, descriptions, feedback)

**Added:** 2026-06-21
**Summary:** Surface what attacks/weapons/statuses/procs actually do — tooltips, gear descriptions, proc/self-cost visibility, and damage-source feedback.

## Notes

There's currently no way to learn what an attack does without already knowing it from the code — picking "Assassinate" off the action list doesn't say what it does or who it targets. Related UI surfaces, all one underlying gap (attacks/weapons/statuses need player-facing descriptions, not just internal effect data):
1. *In-combat action tooltips* — on action buttons, showing effect and target type before committing to a turn.
2. *Weapon/equipment descriptions* — in the inventory/equip screen, listing the attacks a weapon grants **and its passive procs / on-equip effects / self-costs**, so gear choices are informed by actual combat behavior, not just stat deltas.
3. *Passive-proc visibility* — the motivating case (2026-07-08): the Assassin's starting **Vorpal Blade** deals `max(5, 25 - agility*0.4)` recoil self-damage on every hit (`player_attack_hit` proc, `apply_to_owner`), which reads as unexplained "5 armor damage when I attack." The player has no surface anywhere — not the weapon screen, not combat — telling them the weapon bites back. Procs, on-equip effects, and self-damage are entirely invisible today.
4. *In-combat damage-source feedback* — the combat log/HUD should name **where** damage came from (recoil, poison tick, enemy X's move), not just show numbers. `game.gd` already logs "Your armor absorbs N damage" but not the cause; statuses tick silently. This is also the natural payoff surface for the status work (poison/bleed/burn ticks should announce themselves).
5. *Damage-formula legibility* (2026-07-22): each attack/spell's `DamageEffect.damage_expression` is a free-form string scaling off whatever stat the content author chose (`agility * 0.6`, `20 + strength/2`, `spirit * 0.5` — see `resources/effects/*.tres`), with no in-game surface showing the player which stat a given attack scales from. A player can't tell "this weapon wants AGI" without reading source. Likely the same surface as #1/#2 (action tooltip / weapon description) — show the scaling stat, not necessarily the raw expression.

**Priority:** flagged as the **next thing to tackle after the status-effect groundwork** (user, 2026-07-08). The recoil confusion made it concrete — the game hides too much of its own math from the player, which fights the "readable enemies/state, surprise through mechanics not hidden numbers" goal in [[ideas/combat-feel-and-pacing]].

**Damage/status preview design (2026-07-22)** — fleshed out item 1 (action tooltips) into two complementary surfaces feeding one shared computation:
- **Button tooltip (hover, pre-commit)** — full detail: attack name, target mode, and a per-effect breakdown. Damage effects show the literal expression plus the computed value (e.g. `20 + STR × 0.5 = 24 damage`); status/buff effects show status name + duration. The number is the **raw hit only** — evaluated against attacker stats via the existing `DamageEffect.damage_expression`, no target-side armor mitigation simulated. Matches the "legibility over sophistication" principle; armor absorption stays visible in the combat log's existing armor/HP split rather than being folded into the preview. This is also where damage-formula/scaling-stat legibility (item 5 above) lands — the per-effect breakdown surfaces the scaling stat directly.
- **Target overlay (during targeting)** — compact: just the computed number plus a `StatusIcon` instance (subscript stack-count badge when the effect would add to an existing stack) riding on the existing `TargetIndicator` node. Since `TargetIndicator` already reparents per-candidate and updates live on arrow-key cycling, the overlay comes along for free. For `ALL_ENEMIES` attacks, the same overlay stamps onto every spawned indicator at once. `SELF`-targeted actions (Brace, buffs) skip the overlay — no enemy to anchor it to — and rely on the tooltip plus the existing vignette.
- **Shared computation** — a single helper (e.g. `compute_attack_preview(attack_data, source_stats) -> Array[PreviewLine]`) feeds both surfaces, so they can't disagree.
- **Resolves a StatusIcon open question** — using a stack-count badge (rather than repeated icons) here settles the "badge vs. repeated icons" stacking-display decision for `StatusIcon` generally, not just this preview — see [[ideas/combat-ui-widget-scenes]], which tracks extracting `status_icon.tscn` and `action_button.tscn` as the likely home for this UI.

## Shipped

- **Action previews (item 1 + item 5)** (2026-07-22) — the shared `AttackPreview` helper (`scripts/attack_preview.gd`) computes an attack/spell's raw-hit damage + applied statuses from its effects, reusing `StatExprEval` (non-crit, no armor mitigation), and feeds **two surfaces**: the **target overlay** (`scenes/target.tscn` + `target_reticle.gd`, replacing the old `TargetIndicator`) shows the computed number + status icons (with resulting-stack badge) on each aimed enemy; the **action-button hover tooltip** shows name, target mode, and a per-effect breakdown with the humanized scaling expression (`STR × 0.5 = 24 damage`) — covering damage-formula/scaling-stat legibility (item 5). SELF actions keep the vignette; `ALL_ENEMIES` stamps the overlay on every enemy. `TargetTexture` left empty for future reticle art. See [[daily/2026-07-22]].
- Design work started, no player-facing surfaces yet. A **"Combat UI Information Inventory (design-sketch checklist)"** — 10 concern-areas enumerating the legibility gaps this pass targets (elemental/martial statuses, procs, self-costs, damage sources all tagged *invisible today*) — was drafted into [[detailed/gui-design.md]] on 2026-07-09 (see [[daily/2026-07-09]]).

## Remaining

- ~~**Action tooltips** — build `compute_attack_preview()`, the button tooltip UI, and the overlay.~~ ✅ Shipped 2026-07-22 (as `AttackPreview` + target overlay + button tooltip). Follow-ups: tune the overlay screen offset against enemy art; extract `status_icon.tscn`/`action_button.tscn` widgets ([[ideas/combat-ui-widget-scenes]]).
- Weapon/equipment descriptions (incl. procs / on-equip / self-costs).
- Passive-proc visibility.
- Named damage-source feedback in the combat log.

Implementation likely rides on the widget-script work in [[ideas/combat-ui-widget-scenes]] (`action_button.tscn`, `status_icon.tscn`) rather than more code-built nodes in `gui.gd`.
