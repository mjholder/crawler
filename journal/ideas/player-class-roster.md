# Player Class Roster — 10-class stat-coverage matrix

**Added:** 2026-07-04
**Summary:** A 10-class roster giving every stat a build-focus anchor, to unblock content generation and give the balance pass a finite target.

## Notes
Full class roster to unblock content generation and give the balance pass a finite, comparable target — same discipline as the elemental caster kit matrix (build to a shared skeleton, tune one, copy deltas). Each class differentiates primarily through stat block + starting kit/spells, not bespoke mechanics. Classes stay mechanical/archetypal in naming; gothic flavor lives in the Background layer instead, avoiding overlap.

Every one of the 6 stats (STR/DEF/CON/AGI/SPI/LCK) has at least one class where it's the clear build focus. DEF is gear-driven, not growth-driven (no level-up allocation) — so "DEF class" means a class whose starting kit and loot affinity centers a shield/heavy-armor path, not a DEF growth rate.

Existing anchors (kept, revisit stat blocks if roster needs it):
- Warrior — STR/CON primary. Battle axe, plate-adjacent kit.
- Rogue/Assassin — AGI primary. Dodge-and-crit focused.
- Mage — SPI primary. Mana/spellcasting focused.

New — stat-primary coverage:
- Sentinel — DEF-itemization class. Mainhand is a shield (Targe-of-the-Blooded-style weapon with its own attack/bash kit, not a passive block item), offhand free for a lighter buckler (weak DEF/support) or a focus. Fits the shipped `hand_restriction` / `as_offhand_attacks` system (2026-07-03). Growth leans STR/CON like Warrior, but loot pool and starting kit are shield-and-heavy-armor-first, distinguishing it by itemization rather than stat curve.
- Warden — CON primary. The "fight goes long, I outlast it" class — highest HP pool in the roster. Differentiator vs. Sentinel (shield/DEF) and Warrior (balanced STR/CON): Warden trades offense for sheer attrition.
- Fatebinder — LCK primary. Wildcard/gambler identity — crit and variance-forward kit. First class to make LCK a real build rather than a dump stat; also a stress test of LCK's legibility.

New — hybrids (pairs read as a distinct fantasy, not a stat average):
- Crusader — STR + SPI. Melee-forward battle-caster; spends mana on smites/buffs layered onto weapon attacks rather than standalone nukes.
- Blade Dancer — AGI + SPI. Fast, evasive hybrid caster — cantrip/utility-leaning rather than burst nukes.
- Trickster — AGI + LCK. Crit/proc-variance rogue-adjacent hybrid; randomized bonus procs rather than raw dodge stacking. Cross-pollinates with Fatebinder's LCK identity without duplicating it (Fatebinder is caster/gambler-flavored, Trickster is martial).
- Berserker — STR + CON. Glass-cannon-adjacent brute; trades DEF/control for raw offense and a big HP pool.
- Hexweaver — SPI + LCK. Occult fortune-teller caster; hex/curse spellwork with unpredictable/wildcard effects.

Open questions / dependencies:
- Magic-type roster (elements/effect-types with control/burst/utility leans) needs fleshing out, then mapped onto caster-adjacent classes (Mage, Crusader, Blade Dancer, Hexweaver) — may reshape those four.
- Sentinel's shield-mainhand kit needs a detailed design pass (attack shape, bash/riposte verbs).
- Growth rate deltas (`growth_rates` dict per class) not drafted — this entry is stat lean, not stat numbers.
- Starting kit/spell specifics per class are a follow-up authoring pass once names/leans are locked.
- Whether Fatebinder/Hexweaver's wildcard mechanics need new `Effect` subclasses or fit the existing pipeline — worth an architecture check before authoring.
