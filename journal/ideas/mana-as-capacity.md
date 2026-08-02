# Mana as Capacity — SPI Gates, Tomes Carry Potency

**Added:** 2026-07-27
**Summary:** SPI doesn't scale spell damage — it sets max mana, which gates casts-per-floor and which tiers are affordable; spell power is a flat authored number carried by the spell itself.

## Notes
SPI does not scale spell damage. Spell damage is a flat authored number carried by the
spell; SPI sets max mana, which determines how many casts per floor and which tiers are
affordable at all. No separate spell-tier gate — pool size is the gate implicitly.

Asymmetric with weapons by design: weapons = power + stat scaling (martials express
through investment), spells = power only (casters express through acquisition and
preparation). Pillar: martial power comes from stats, caster power comes from content.

Mana regen: full on node entry, partial between events within a floor. This is what
makes capacity-SPI work — the binding constraint moves from within-fight (where the
pool never binds and surplus SPI is worth zero) to across-floor. Regen percentage is
the primary tuning knob for the value of a SPI point.

Early spells falling off completely is accepted and intended, same as white gear for
martials.

**Open: the dry-mage floor.** Zero-cost cantrips are now a fixed number that never
scales, so the fallback decays across the run. Options: focus grants a weak attack
action, cantrip damage sourced from something non-SPI, or accept that dry means weapon
attack.

**Open: scale mismatch.** Existing docs ([[ideas/attribute-distribution-leveling]])
assume ~8 mana per basic spell and ~6 starting casts; the illustrative
Ignite/Fireball/Immolate scale is 25/35/50. Pick a scale before authoring content.

Overlaps with [[ideas/spell-casting-system]] (mana derivation, prep slots) and
[[ideas/attribute-distribution-leveling]] (SPI/mana_modifier economy).

## Shipped
- **Flat authored spell power (2026-08-01).** `SpellData.power` carries a spell's damage as a flat
  number; spells evaluate the uniform `power * coeff + scale * scaling` form with the stat term zeroed
  (`scale`/`scaling` = 0), so SPI no longer touches spell damage. `player.spell_context_for` builds the
  context; `game.gd`/`AttackPreview` thread it through cast + preview; `damage_spi_half` and
  `chain_lightning_damage` migrated off `spirit * 0.5`. Numbers seeded at 12 (≈ old value at SPI 25),
  designer knobs from here. See [[daily/2026-08-01]] and [[ideas/weapon-anatomy-power-and-scaling]].

## Remaining
- Reconcile the mana-cost scale (8/basic vs. 25–50 illustrative spells) before authoring
  content — Sparks (0-mana cantrip) currently ties the 5-mana bolts at 12.
- Resolve the dry-mage floor fallback (cantrip damage source or accept weapon-only).
