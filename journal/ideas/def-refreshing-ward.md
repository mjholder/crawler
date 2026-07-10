# DEF as refreshing ward (replace percentage reduction)

**Added:** 2026-07-06
**Summary:** Replaces linear DEF mitigation with a per-round armor buffer; shipped as `armor`, only a balance pass remains.

## Notes
Replaces the linear `1 - DEF/100` mitigation. DEF becomes a per-round ward: a buffer equal to (roughly) the DEF value that absorbs incoming damage before it reaches HP, refreshing at the *start of each round*. Damage beyond the remaining ward bleeds through to HP.

Why over the alternatives (low-loot-DEF, or keeping percentage): the percentage formula is linear with no soft cap — DEF 100 = literal immunity, and every point is worth a flat 1% so a dedicated stacker climbs straight to the wall. Just handing out little DEF in loot holds the *average* player down but can't hold the *ceiling* of the Sentinel, which is explicitly a DEF-itemization class meant to stack it. Ward fixes this structurally instead of by tuning.

Advantages:
- Immunity is impossible by construction — a big enough single hit pierces the ward straight to HP no matter how high DEF goes. Real soft-gating, not a clamp.
- Dead legible: "50 armor eats 50 damage a round, then I bleed." Board-game clear, arguably more so than percentage.
- Auto-scales-down across acts for free — a fixed ward is huge vs Act 1 numbers, a rounding error vs Act 3 nukes, with no formula change. Does the "each act balanced against expected power" work automatically.
- Makes DEF and AGI complementary, not redundant: dodge is strong vs *few big hits* (decay rarely bites, each dodge saves a lot), ward is strong vs *flurries of small hits* (soaks them whole) and weak vs *one big nuke* (pierced). Two near-opposite, legible enemy-design axes → "some builds favored, nothing absolute."
- Differentiates the two tanks: Sentinel outlasts via refreshing ward; Warden outlasts via a raw CON HP pool that doesn't come back each round. Two distinct "I don't die" fantasies.

Risk: if ward ever exceeds a round's *total* incoming, chip is fully nullified for that round — immunity in a new coat. Self-correcting where percentage wasn't: multi-enemy rounds stack incoming past the ward, and the natural scale-down erodes it over the run. Keep base ward modest enough to *blunt* attrition, not erase it, to stay honest with the dungeon-wide-attrition tension.

Implementation notes: refresh at start-of-round (not per player turn) — that's what makes the flurry interaction bite. Scaffolding exists: round counter in `game.gd`, reroute the `take_damage` → `_apply_defense` path, DEF `stat_modifiers` from statuses become "smaller ward next refresh." Armor-pierce is a clean future lever ("ignores/reduces ward"). AGI/dodge-decay stays as-is (see [[ideas/consecutive-attack-dodge-decay]], 2026-07-05).

## Shipped
**(2026-07-07):** implemented under the name **armor** (not "ward"). `armor`/`max_armor` on both `Player` and `Enemy`, `refresh_armor()` at round start (`player.begin_turn()` / `CombatEvent._on_round_started()` off `game.player_turn_started`), `_apply_defense()` rewritten to buffer absorption with no 1-damage floor, `armor_changed`/`armor_absorbed` signals, and an armor HUD (player bar + enemy `HealthBar` overlay). Applied to enemies too. See [[design.md]] "DEF is a refreshing per-round armor buffer…" and [[daily/2026-07-07]]. Future lever noted: armor-pierce.

## Remaining
A balance pass on DEF/armor values (old percentage tuning is stale).
