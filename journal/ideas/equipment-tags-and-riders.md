# Equipment Tags and Riders — Two Kinds of Rarity Payload

**Added:** 2026-07-28
**Summary:** Split rare-gear bonuses into numeric TAGS (roll, compose with power/scaling) and binary RIDERS (rarity-gated, never rolled on commons) so higher tiers gain new behavior instead of just bigger numbers.

## Notes
Rare gear carries two mechanically distinct kinds of bonus, and keeping them separate
is what stops higher tiers from being strictly better while preserving the
smithing/rarity law ([[ideas/weapon-anatomy-power-and-scaling]]).

**TAGS** — numeric, rolled on loot at rare tier and above. A tag is its own resource
type that reuses the existing equipment vocabulary wholesale: `stat_modifiers`,
`proc_effects`, `conditional_modifiers` already have the right shape. Tags add only two
new fields on top: `power_delta` and `scaling_delta`. Example: "Fine Balance" (rare+)
raises scaling so all of the weapon's attacks move from `X + STR*0.5` to `X + STR`.
Composed at read time onto the item instance, never written into the base `.tres`.

**RIDERS** — binary, non-numeric, rarity-only, never rolled on commons. Examples: +1
stack to statuses this weapon applies; an innate spell on a focus. A rider is what
answers the tier-transition sting — a smithed common can never match one, because
commons simply don't have them, so "smithing moves power, rarity moves scaling"
survives intact. Riders are also deliberately hard to price against flat damage, which
is the point: the comparison should be an interesting choice, not a dominated one.

Watch +1 stack specifically. On a STACK-policy DoT it compounds over a fight and
behaves closer to a multiplier than a bonus. It also interacts with crit (crit doubles
STACK-policy stacks — see [[ideas/luck-crit-loot-quality]]), so the same rider is worth
noticeably more on poison than on fire, which uses REFRESH and doesn't benefit.

Innate spell as a focus rider is worth more than any stat roll, because innate spells
bypass prep slots ([[ideas/spell-casting-system]]) — it isn't "a spell attached to a
focus," it's a free prep slot that arrives pre-filled. Rare tier minimum, and it should
probably only ever carry spells the player wouldn't voluntarily prepare, or it distorts
the whole repertoire decision.

**ARMOR** — same tag system, no scaling axis. Armor has no power/scaling split for a
structural reason: DEF is the output, not an input. A weapon converts STR into damage
so there's a rate to tune; the ward IS the stat, and scaling it off CON would break
one-stat-one-job. So armor tags move the number, and the interesting axis — if we want
one — is time rather than magnitude. The ward already has a temporal life weapons don't
([[ideas/def-refreshing-ward]]): it refreshes each round, it can be shattered, it can be
pierced, big hits blow through it. Sketches, none decided: shatter resistance or reduced
shatter duration; flat pierce reduction ([[ideas/pierce-as-percentage-split]]); unspent
ward carrying over to the next round up to a cap; a first-hit-per-round cap that buys
partial exemption from "big hits pierce to HP."

Deliberately not pursuing armor behavior yet. Six armor slots against one weapon slot
means six behavioral rules in the player's head every round if every piece rolls one,
and legibility dies. If it happens at all, it should concentrate in one or two identity
slots (torso, head) while boots and gloves stay pure numbers. Recorded so the time-axis
insight doesn't evaporate, not because it needs building.

**Open:** which tags are weapon-only, armor-only, or universal.
**Open:** how many tag slots an item has, and whether tier raises the count or only the
quality of what can roll.
**Open:** whether riders roll independently of tags or are a rare tag subtype with no
numeric payload.
**Open:** loot quality math (LCK) determines tag roll odds — still deferred, tracked in
[[ideas/luck-crit-loot-quality]].

## Shipped
Phase 17 (2026-07-31) — see [[architecture.md]] §4, [[daily/2026-07-31]].
- **TAGS** defined: `TagData` resource (`power_delta`, `scaling_delta` + `stat_modifiers` /
  `proc_effects` / `conditional_modifiers`), composed onto an `ItemInstance` at read time. Tags are
  the only path that may move both power and scaling. Example authored: `resources/tags/fine_balance.tres`.
- Tag-added procs subscribe via `Equipment.item_instance.effective_proc_effects()`; tag stat_mods /
  conditionals fold through `Player.get_effective_stat`.
- Only TAGS are built. RIDERS remain a separate, unbuilt concept.

## Remaining
- **RIDERS** — binary, rarity-gated behavior (weapon +1 status stack; focus innate spell). Not
  modeled yet; still open, incl. the +1-STACK-vs-crit interaction and the rarity gate.
- Tag slot count / quality-by-tier, and weapon/armor/universal tag scoping — still open.
- Wire LCK loot-quality math into tag roll odds once [[ideas/luck-crit-loot-quality]]'s
  loot-quality piece lands (no drop generation yet — tags are attached via code/debug only).
- **ARMOR** tags + time-axis behavior stays parked — no build work planned (the generic
  `ItemInstance` already accepts armor tags, so it slots in with no re-plumbing).
