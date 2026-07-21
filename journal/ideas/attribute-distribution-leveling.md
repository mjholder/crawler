# Attribute Distribution, Leveling & Resource-Stat Economy

**Added:** 2026-07-20
**Summary:** Balancing the level 1–10 arc (~3 levels/act, 3 acts) so a focused build reaches 100 in its main attribute but has to invest to get there.

## Notes

**Starting stats & growth**
- Base attribute score: 10 (all stats).
- Primary: +15 at start (→25), +6/level.
- Secondary: +5 at start (→15), +3/level.
- Tertiary: base 10, no class growth.
- Free points: 5 per level-up (45 total across levels 1–10).

Deterministic values at Lv10 before spending free points: primary 79, secondary 42, tertiary 10. Capping primary at 100 costs ~21 free points, leaving ~24 to spread. A tunnel-vision primary build hits 100 around Lv8 (25→80 at Lv6, 91 Lv7, 100+ Lv8).

**100 = balance point, not a cap**

No hard ceiling. 100-primary + solid secondaries is the comfortable default. Spending past 100 is deliberate specialization — strong peaks bought with real weaknesses (glass cannon). Fits soft-gating: nothing stops the min-maxer, the point economy just makes them pay in coverage. Weakness only bites if low tertiaries hurt, so the balance lives in the stat effects, not the totals.

**CON consolidation**

Remove `class_health_bonus` entirely; roll it into CON. `max_health = effective_CON * health_modifier` (currently 2.0), nothing else. More readable — CON *is* your HP. Consequence: no safety net. Tertiary-CON class at CON 10 = 20 HP, one-shottable by design. Durability spread ~4:1 (200 HP primary-CON vs ~50 HP squishy). Defensive tools become load-bearing, not optional, for low-CON classes.

**SPI mirror (symmetry)**

Same shape as CON. Consider rolling `class_mana_bonus` into SPI for the same readability win. `max_mana = effective_SPI * mana_modifier` (2.0).

**Spell / cantrip economy**
- Cantrips: cost 0. The caster's equivalent of a weapon — a free baseline action so an out-of-mana mage still does (weak) chip damage. Always available, weak by design.
- Basic spells: cost 8. Starting primary-SPI mage (25 SPI → 50 mana) gets ~6 casts (target was 5–7). At 100 SPI (200 mana) = ~25 casts. Basics stay cheap forever; power progression comes from bigger/pricier spells and gear, not spammier basics.
- Squishy-mage survival = mitigation they spend for, not HP. Candidates: ward spell (temp armor buffer on existing DEF system), dodge/blur spell (temp AGI), robe access (weak by armor triangle). Open question: prepared spell (opportunity cost) vs class-innate.

**Dependencies / open**
- Per-spell `mana_cost` is currently unauthored (defaults 0.0) — needs populating; 8 is the anchor for "basic."
- Defensive-tool delivery for casters undecided (prepared vs innate).
- `health_modifier` / `mana_modifier` (2.0) only meaningful vs. enemy damage numbers — leave parked until playtest.

Overlaps with [[ideas/balance-legibility-baseline]] (stat → output conversion) and [[ideas/spell-casting-system]] (mana_cost authoring, prep slots).

## Shipped

## Remaining

Everything — this is a design proposal, not yet implemented.
