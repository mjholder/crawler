# Elemental Caster Kits — a Comparable Matrix

**Added:** 2026-06-28
**Summary:** Mirror the Pyromancer kit skeleton (weapon + signature status + utility spell + class) across elements so they balance like-for-like.

## Notes

The Pyromancer (fire) establishes a repeatable kit template that should be mirrored across elements so they balance against each other like-for-like: a caster **weapon** with a three-attack shape (*charge-up → single AOE blast → DoT/control AOE*), one **signature status**, a **utility/defensive spell**, and a **glass-cannon-ish class** that starts with it. Building each element to the same skeleton means tuning one and copying the deltas instead of balancing every kit from scratch.

Draft elements:
- **Fire** *(shipped 2026-06-28, see [[daily/2026-06-28]])* — `burn` DoT; Pyre Scepter (Kindle / Flameburst / Immolate) + Flicker dodge + Pyromancer class.
- **Frost** — `chill` (AGI down; freeze/skip-turn at high stacks); control-leaning, tankier class. Utility: barrier or slow.
- **Storm / Lightning** — chain-hit attacks that arc between enemies; `shock` (target takes +X% damage); high-variance burst. Utility: haste / extra action.
- **Stone / Earth** — `barrier` absorb; DEF-scaling "bruiser caster," slow but durable. Utility: taunt / guard.
- **Blight** — leans on existing `poison` / `bleed`; an attrition class that *wants* long fights (counterpoint to burst). Utility: spread / transfer DoT.
- **Radiant** — heal + smite hybrid, bonus vs undead (ties into the world lore / Forgotten Entity thread). Utility: cleanse.

Each element's signature status is the balance anchor — see [[ideas/status-effect-vocabulary]]. Connects to the Identity/Expression arc in [[ideas/run-structure-and-act-progression]] (gear that combos with a spell is the Act 2 hook).

## Shipped

Only the template kit so far: **Fire** *(2026-06-28, see [[daily/2026-06-28]])* — `burn` DoT, Pyre Scepter (Kindle / Flameburst / Immolate), Flicker dodge, and the Pyromancer class, authored via the content pipeline. Separately, per-element **signature status systems** (Fire burst-burn, Lightning chain, Frost armor-pierce, Poison) landed 2026-07-09 under the [[ideas/elemental-signature-identities]] work — note that pass merged Frost/Ice into one element and **dropped `chill`** in favor of armor-pierce.

## Remaining

Author the full kits (weapon + signature status + utility spell + glass-cannon class) for every non-Fire element to the shared skeleton, then tune one and copy the deltas. Reconcile the Frost row against the shipped "chill dropped, pierce instead" decision.
