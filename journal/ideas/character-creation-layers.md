# Character Creation Layers — Background + Patron Saint

**Added:** 2026-05-30
**Summary:** Three-part build identity — Class, Background, Patron Saint — with saint tiers that ascend across acts.

## Notes
Add two new layers to character creation alongside the existing class pick, giving the player a three-part build identity. Inspired by Elder Scrolls birthsigns and Daggerfall-era character creation, but themed to the gothic tone of this project.

**Three layers, three roles:**
- **Class** *(existing)* — *what you can do.* Stats, growth rates, starting loadout, spell roster. The trained archetype.
- **Background** *(new)* — *who you were.* Civilians take up arms in trying times. Small stat shift, starting gold, one unique passive. Static across the entire run.
- **Patron Saint** *(new)* — *what watches over you.* A divine contract that intervenes at dramatic moments. Evolves across the three acts (Survival / Identity / Expression). Often comes with a tithe.

Synergies are meaningful but not required — a Mage / Cloistered Scholar / Saint of the Veil reads as a deliberate caster build, while a Warrior under Saint of the Veil is a thematic mess the player can still make work. Builds-by-non-synergy are a feature.

**Background design**
- Minor stat bump (and optionally a small drawback to match the gothic tone).
- Starting gold value.
- One unique, static passive tied to the character's former life.
- Framing: "civilians forced to adventure." Each background should answer *what did this person do before, and what trace did it leave on them?*
- Example: **Failed Business Owner** — starts with more gold, gains a gold-reward multiplier on event rewards, and gets a shop price modifier (cheaper buys, better sells).
- Other archetypes to explore: Disgraced Knight, Plague Survivor, Cloistered Scholar, Tomb Robber, Heretic, Wayward Acolyte.

**Patron Saint design**
- Each saint is a lineage of three `BlessingData` tiers — one per act. At act transitions, the current tier is removed and the next is applied. New `lineage_id: StringName` field on `BlessingData` ties them together.
- Triggers are *conditional and dramatic*, not always-on stat bumps. Saints feel like intervention, not passive buffs.
- Each tier broadens the trigger and/or adds a new dimension; numerical magnitude is the weakest lever.
- Example: **Saint of Ambush**
  - *Tier 1* — first attack of combat deals 2x damage.
  - *Tier 2* — first attack of every round deals 3x damage and applies bleed.
  - *Tier 3* — first attack against a full-HP enemy is a guaranteed crit, restores HP on kill, applies bleed.
- **Tithe scales with tier.** Late-game saints are dangerous pacts: bigger boons, steeper costs. (e.g. Tier 2 Ambush also starts every combat at −10% HP; Tier 3 lets enemies first-strike you too.)
- Saints are *unique* — run-acquired blessings can give general bonuses, but only saints provide their specific signature shape. This protects the choice from being outscaled by late-game loot.

**Ascension via shrine events**
- A new event type: shrine/altar at the end of each act. The player visits their saint's shrine, makes an offering, and ascends to the next tier.
- Offers a meaningful choice — *ascend* (take the next tier and its tithe) or *decline* (keep current tier, take gold/items instead). Reinforces the dark-bargain feel and gives saints diegetic presence in the world.

**Implementation surfaces**

*New:*
- `BackgroundData` resource — stat shift, `starting_gold`, passive effect references.
- `starting_background: BackgroundData` and `starting_patron: BlessingData` fields on the character creation flow.
- `lineage_id` field on `BlessingData`.
- New modifier fields the failed-business-owner needs: a player-side gold-reward multiplier read by `_apply_rewards`, and a player-side shop price multiplier stacked onto `ShopData`'s existing multipliers.
- Shrine event type (mirrors existing event pattern; lives in dungeon slot system).

*Reused:*
- `add_blessing` / `remove_blessing` already handle tier swaps cleanly.
- `BlessingData.subscriptions` already supports conditional/proc triggers via the lifecycle signal bus.
- Character creation panel just needs two more pick steps after class.

**Open questions for plan-time**
- How many backgrounds and saints? First pass: 6 of each (matches the six existing stats; 6×6×N classes is plenty of variety without overwhelming).
- Do backgrounds have drawbacks (to rhyme with saint tithes), or stay net-positive?
- What happens if the player skips a shrine? (Defer tier-up to a later shrine? Lose the tier entirely?)
- Are shrines guaranteed at end-of-act, or do they appear in a node slot the player has to navigate to?

**Parked / v2 directions**
- *Branching saint evolutions* — Act 2 offers 2–3 paths within the same saint. Lineage system already supports this; just adds authoring + design work.
- *Non-combat saints* — Saint of the Locked Door, Saint of Liars, etc. — saints whose signature triggers fire on skill checks or dialogue rather than combat. Would broaden the appeal of the choice for build types that aren't combat-focused.

## Shipped
- **Phase 1 (2026-06-07):** `BackgroundData` + `PatronSaintData` (+ `lineage_id` on `BlessingData`), player integration (`_setup_background`/`_setup_patron`, gold-reward/shop multipliers), content-editor authoring, hand-built 4-step wizard UI, sample content. Saints ship at tier 1, fully playable; `ascend_patron()` and `_patron_tier_index` are in place. See [[design.md]] and [[daily/2026-06-07]].
- **Phase 2 — shrine ascension (2026-06-21):** generic `ShrineEvent` + `ShrineMapNode` + `ShrinePanel`; player pays a gold tithe to `ascend_patron()` (replace, never stack) or leaves keeping gold and tier. See [[daily/2026-06-21]].
- **Phase 2 — act progression (2026-06-27 / 2026-06-28):** shrine reframed as an end-of-act **town hub** (`EndActMapNode`/`EndActEvent` + `TownPanel`); Travel Onward swaps the live `WorldMap` for the next act's scene, or wins the run; run-ending victory moved off the boss onto the final act's end node; save tracks `current_act` + `active_act_scene_path`. See [[daily/2026-06-27]] and [[daily/2026-06-28]].

## Remaining
- The "first attack deals Nx damage" proc still needs a new effect type (the sample Saint of Ambush currently expresses its tiers via `stat_modifiers` + a tier-3 heal-on-kill subscription).
- Real authored act 2 / act 3 maps and per-act `ascension_cost` scaling (placeholder act 2 is a standalone copy).
- Parked / v2: branching saint evolutions, non-combat saints.
