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
*(Resolved Phase 22: because a decaying DoT's single `stacks` number was both lifetime AND
per-tick multiplier, +1 stack read as "harder" as much as "longer" — so the lever was split into
two, `StackBonusRider` (longer) and `PotencyRider` (harder). See Shipped below.)*

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

Phase 18 (2026-08-03) — see [[architecture.md]] §4, [[daily/2026-08-03]].
- **RIDERS** defined as a polymorphic family: `RiderData` base (`rider_name`, `description`,
  `min_rarity`, default RARE) with `StackBonusRider` (`bonus_stacks`) and `InnateSpellRider`
  (`spell`). Composed onto `ItemInstance.riders` and serialized alongside tags.
- **The rarity gate lives in one place** — `ItemInstance.effective_riders()` returns only riders
  whose `min_rarity <= rarity`; `stack_bonus()` / `granted_innate_spells()` read only through it,
  so a smithed common never gains a rider.
- **Stack rider** threads through the weapon context: `weapon_context_for` sets
  `ctx["bonus_stacks"] = inst.stack_bonus()`, and `StatusEffect.apply` folds it in *before* the
  crit multiply — so a crit doubles `(base + bonus)` together, exactly the called-out interaction.
  Scope is statuses applied through the weapon's *attack* effects; proc-applied statuses pass no
  context and are unaffected (accepted).
- **Innate-spell rider** is hand-local: `_build_hand_actions` registers `granted_innate_spells()`
  into `_hand_spells[hand]`, which is where `_do_cast` resolves — so it bypasses prep slots with no
  repertoire changes.
- Examples authored: `resources/riders/venomous.tres` (StackBonusRider), `resources/riders/sparkbound.tres`
  (InnateSpellRider → Sparks). Attach is code/debug-only (`ItemInstance.add_rider`) — no loot roll or UI.

Phase 21 (2026-08-04) — content tooling + baked equipment payload. See [[architecture.md]] §4,
[[design.md]], [[daily/2026-08-04]].
- **Authoring parity**: `TagData` was missing from `schema.json` (never in the `export_schema.gd`
  allowlist) — fixed, with a `TagData` annotations entry. Editor gains **Tags** and **Riders** in
  `CONTENT_TYPES`; the ＋New flow prompts for the concrete rider subclass. New `refresh_schema` MCP
  tool re-reads the schema from disk without a sidecar restart. `mcp-authoring.md` documents both.
- **Baked payload → fixed / named magic items**: `EquipmentData` gains `base_rarity`, `default_tags`,
  `default_riders`; `ItemInstance.wrap()` seeds them onto fresh items only (save/load authoritative,
  no double-seed). This is the first way to attach tags/riders to a specific item without code.
  Example: `resources/equipment/weapons/serpents_kiss.tres` (RARE, bakes Venomous).

Phase 22 (2026-08-04) — DoT riders split into two orthogonal levers. See [[architecture.md]] §4,
[[design.md]], [[daily/2026-08-04]].
- The single `stacks` number on a `stack_decays` DoT is both lifetime and per-tick multiplier, so
  `StackBonusRider`'s +1 read as "harder" as much as "longer." Split into two levers: **`StackBonusRider`**
  (`bonus_stacks`, *longer* — more turns) and **`PotencyRider`** (`potency_bonus`, *harder* — flat
  per-stack tick damage, same duration). Potency persists on `StatusInstance.potency`, added per stack in
  `apply_tick` before the stack multiply, un-crit-scaled; re-application keeps the strongest.
- Fixed a lying **attack preview**: it showed a `stack_decays` status's authored `duration` (poison = 3)
  and ignored the equipped rider. Now folds the weapon's `bonus_stacks` into the shown count and displays
  the real lifetime (= stacks), matching the live status readout.
- Examples: `resources/riders/virulent.tres` (PotencyRider, now baked on Serpent's Kiss);
  `resources/riders/venomous.tres` stays a StackBonusRider (the longer lever).

## Remaining
- Tag slot count / quality-by-tier, and weapon/armor/universal tag & rider scoping — still open.
- Wire LCK loot-quality math into tag/rider *roll* odds once [[ideas/luck-crit-loot-quality]] lands.
  Rolled drops still don't exist (no drop generation) — but tags/riders can now be **baked** onto an
  authored item via `default_tags`/`default_riders`/`base_rarity`, so hand-placed magic items are no
  longer code/debug-only.
- Optional guard: lint/warn when a baked rider's `min_rarity` exceeds the item's `base_rarity`
  (silently inert today).
- **ARMOR** tags + time-axis behavior stays parked — no build work planned (the generic
  `ItemInstance` already accepts armor tags, so it slots in with no re-plumbing).
