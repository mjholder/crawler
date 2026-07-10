# Balance Legibility Baseline (stat → effect budget)

**Added:** 2026-06-28
**Summary:** A reference doc pinning how each stat converts to outputs, target combat length, per-act curves, and item power budgets.

## Notes

Before trial-and-error tuning can converge, the numbers need to be *legible* — there's currently no answer to "what is 1 point of SPI worth?" or "how much should a tier-1 weapon hit for?" Capture a reference (candidate: `journal/detailed/balance.md`) pinning down: how each stat converts to its outputs (CON→max HP, SPI→mana + spell scaling, AGI→hit/dodge, DEF→mitigation, STR→melee, LCK→crit/wildcard), the target combat length (5–8 player turns, per [[ideas/combat-feel-and-pacing]]), the expected player stat/HP curve per act (per [[ideas/run-structure-and-act-progression]]), and a rough power budget per item tier so "this feels off" becomes "this is 2× budget." Doesn't lock anything down — it's a yardstick so playtests produce decisions instead of vibes. First step: audit the actual formulas in code (`take_damage`, max-health / max-mana derivation, any hit/dodge roll) and write down what they currently *are*. See [[detailed/character.md]].
