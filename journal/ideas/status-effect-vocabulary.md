# Status-Effect Vocabulary Expansion

**Added:** 2026-06-28
**Summary:** Grow the status "verb" roster (chill, weaken, haste, shock, barrier, mark), triaged by authoring-only vs. needs-code.

## Notes

Combat depth and balance both rest on the set of status "verbs" available. Current roster: `poison`, `bleed`, `stun`, `regen`, `burn`. The Effect System v2 / `StatusData` pipeline already supports `stat_modifiers`, `on_apply`/`on_tick`/`on_expire`, `prevents_action`, and stack policies, so several of these are authoring-only (no new code):
- **chill** — passive AGI debuff; at N stacks escalate to a freeze (`prevents_action`). Frost signature. *(authoring-only)*
- **weaken** — STR/SPI debuff to soften enemy output. *(authoring-only)*
- **haste** — sustained AGI buff / chance at an extra action (Flicker is the one-off spike; haste is the sustained form). *(authoring-only)*
- **shock / vulnerable** — target takes +X% damage. Needs a damage-amp hook — check whether `take_damage`/`DamageEffect` can read a multiplier status. *(likely needs code)*
- **barrier / shield** — flat absorb pool consumed before HP; not expressible as a `stat_modifier`. *(needs code)*
- **mark** — next hit auto-crits / bonus-damages a target; pairs with the "first attack deals Nx" proc noted under the Patron Saint entry. *(needs code)*

The authoring-only vs needs-code split is itself useful triage. See [[design.md]] Effect System v2.

## Shipped

Nothing from this specific verb list. The 2026-07-09 elemental/martial status-verb pass (see [[design.md]] "Elemental & martial status-verb systems", [[daily/2026-07-09]]) added a *different* set of verbs (burst-burn, chain-lightning, armor-pierce, bleed, shatter, brace) and **dropped `chill`** — Frost merged into armor-pierce rather than an AGI-down/freeze status.

## Remaining

`weaken`, `haste`, `shock/vulnerable`, `barrier/shield`, and `mark` are all still unbuilt; `chill` is superseded by the pierce decision. The authoring-only ones (weaken, haste) are `.tres` work; shock/barrier/mark still need the code hooks noted above.
