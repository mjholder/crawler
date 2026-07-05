# Ideas & Backlog

Loose ideas, future directions, and things that aren't ready to be tasks yet.
No commitment implied — this is a thinking space.

Resolved ideas (shipped or dropped) are moved out to [[ideas-archive.md]] to keep this
backlog lean. Ideas with a foundation shipped but real work left stay here as `partially done`.

---

## Format

**Idea:** [Short title]
**Added:** YYYY-MM-DD
**Notes:** [Free-form description, rough thoughts, inspiration sources]
**Status:** `raw` | `worth exploring` | `partially done` | `shelved` | `moved to plan`
(`completed` and `abandoned` ideas move to [[ideas-archive.md]].)

---

**Idea:** Player Class Roster — 10-class stat-coverage matrix
**Added:** 2026-07-04
**Notes:** Full class roster to unblock content generation and give the balance pass a finite, comparable target — same discipline as the elemental caster kit matrix (build to a shared skeleton, tune one, copy deltas). Each class differentiates primarily through stat block + starting kit/spells, not bespoke mechanics. Classes stay mechanical/archetypal in naming; gothic flavor lives in the Background layer instead, avoiding overlap.

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
**Status:** `worth exploring`

---

**Idea:** Per-Hand Weapon Restriction + Offhand Moveset
**Added:** 2026-07-03
**Notes:** Weapons should carry a `hand_restriction` enum (`MAINHAND_ONLY`, `OFFHAND_ONLY`, `EITHER`) so the equip UI can enforce which slot they're dragged into. Default is `MAINHAND_ONLY` — existing weapons need no changes. For weapons flagged `EITHER`, an optional `as_offhand_attacks` array defines a different moveset when the weapon is in the offhand slot; if omitted, `attacks` is used for both hands. The existing `offhand_attacks` field on `WeaponData` should be renamed `locked_offhand_attacks` to disambiguate — it means "actions the locked offhand gets when *this* two-hander is in the mainhand," not "what this weapon does when *it* is in the offhand." Needs a detailed design pass before implementing — the rename touches content and `_rebuild_hand_actions()`.
**Status:** `moved to plan` — implemented 2026-07-03; scope grew to include a hand-selection UI (highlight + arrow-cycle, mirroring combat targeting) and animated mirrored offhand weapons. See [[design.md]] — [[daily/2026-07-03]].

---

**Idea**: Enemy Attack Patterns (Sequenced Moves + Telegraphing)

**Added**: 2026-06-30

**Notes**:

Every enemy currently has exactly one hardcoded behavior via _perform_action() override — no variety turn to turn. This is the enemy-side counterpart to the dual-action combat idea: once the player has more to decide per turn, enemies should too, and telegraphing what's coming gives the player something concrete to react to with their new second action (brace vs. attack vs. defensive spell).
Core structure — fixed sequence, not weighted/random (for v1):

New EnemyPatternData resource: an ordered list of "moves," each one modeled after the existing AttackData shape (name, target_mode, effects, icon/description) so enemy moves reuse the same Effect subclasses (DamageEffect, StatusEffect, etc.) already driving player attacks and spells — no new effect system needed.
Enemy gains an optional pattern: EnemyPatternData export and an instance-level _pattern_index: int cursor. Multiple enemies of the same type in one fight naturally run independent cursors since the index lives on the instance.
Base _perform_action() becomes data-driven when a pattern is assigned: read pattern.moves[_pattern_index], apply its effects, advance the cursor (wrapping at the end — loop the sequence).
This is additive, not a replacement for the existing override hook — subclasses that need fully custom/code-driven behavior (boss phase transitions, conditional logic) still override _perform_action() directly. Patterns are for the common case; overrides remain for the special case.

Why fixed sequence first, not weighted/reactive:

A weighted pool (move chosen by rolled probability, possibly conditional on HP/state) is more organic but harder to telegraph honestly — you either commit to the roll early and telegraph the result, or show the player a probability, which is a UX problem of its own. A fixed sequence makes telegraphing trivial: "next move" is just pattern.moves[_pattern_index] before it's consumed, so the UI can peek at it for free. Weighted/reactive patterns are worth exploring later as a distinct extension, not a v1 requirement.
Telegraphing — **decided (2026-07-01): no explicit peek-ahead HUD.** The original idea
here was to surface the upcoming move (icon/label) on the EnemyHUD before the enemy acts.
Dropped in favor of **discovery through play**: the player learns a pattern by living
through it (the wind-up *animation* and applied status icons are the telegraph), not by
reading a "next move" label. This is the deliberate read of the **Combat Feel & Pacing**
principle — "visible states telegraph intent without explicitly showing next-turn damage…
the player learns what those states mean through experience." `peek_next_move()` stays in
code as a harmless accessor (useful for tests/debug) but drives no UI. Note this also
weakens the earlier "fixed sequence makes telegraphing trivial" argument for fixed-over-
weighted — but fixed sequence stays the v1 choice on its own merits (simpler, learnable,
authorable) and weighted/reactive remains the deferred extension.
Deferred / explicitly out of scope for this pass:

Weighted or probability-based move selection.
Patterns that branch based on player state (e.g. enemy reacts to the player having braced last turn) — this couples enemy AI to player action history and is a meaningfully bigger step than a self-contained sequence cursor. Flag as a future extension once dual-action combat and basic patterns both exist.

Status: partially done — see [[design.md]] and [[daily/2026-07-01]].
Shipped (2026-07-01): `EnemyMoveData` + `EnemyPatternData` resources, the optional `pattern` export + per-instance cursor on `Enemy`, data-driven `_emit_attack()` reusing the existing `Effect` pipeline, `PLAYER`/`SELF` targeting, content-editor schema registration, and a sample skeleton pattern (`skeleton_skirmisher.tscn`). Additive to the `_perform_action()` override hook.
Dropped (2026-07-01): the explicit **telegraphing HUD** — patterns are meant to be learned through play, not read off a label (see the Telegraphing note above). `peek_next_move()` remains as a code-only accessor.
Remaining: per-move sound wiring, and the deferred **weighted/reactive** selection extension.

---

**Idea**: Dual-Action Combat (Mainhand / Offhand)

**Added**: 2026-06-30

**Notes**:

Combat currently gives the player one action per turn (attack, or a registered weapon action), which makes turns feel flat — click one button, repeat. Proposal: split the turn into two independent action slots, one per hand, gated separately rather than sharing a turn-wide action count.
Structure:

Each hand has its own action(s) and its own "used this turn" flag (_mainhand_used, _offhand_used), both reset at the start of the player's turn.
Actions can be used in any order — mainhand and offhand aren't sequenced, they're just two independently-gated buttons (or button groups) that disable once spent.
A new End Turn button lets the player explicitly pass — including declining to use a hand at all. Turn no longer auto-ends on the first action; execute_action sets a hand's _used flag instead of emitting turn_ended directly.
Consumables and cantrips keep their existing free-action behavior (no turn cost) — this system only governs mainhand/offhand.

What each hand can grant:

Mainhand: attack (existing), or spell casting for casters.
Offhand: a shield → Brace/Parry (defensive, likely SELF-targeted, possibly a "reduce/negate next incoming hit" duration effect); a second weapon → a second attack-like action; a focus → a second spell slot or a defensive cantrip.
Unarmed is a real loadout, not a null case — bare mainhand and/or offhand grant a baseline punch action rather than nothing.

Two-handed weapons — the open question:

An empty (unequipped) offhand and a locked offhand (from a two-handed weapon) are explicitly not the same outcome. Empty offhand still yields whatever baseline (e.g. unarmed punch) applies. Locked offhand means the two-handed weapon has to compensate for the lost second action somehow — candidate approaches: the weapon grants actions for both "hands" itself (e.g. a heavy swing that occupies the mainhand slot plus a follow-through that occupies the offhand slot), or the weapon's single action is deliberately stronger/more complex to offset losing the second button. Not resolved — needs its own pass once the base two-action system is in.
Complementary idea (separate thread): enemy attack pattern system — giving enemies multiple actions/telegraphed sequences instead of one fixed _perform_action — pairs well with this since the player having two actions to allocate makes "what is the enemy about to do" a meaningful thing to react to. Worth exploring together but tracked separately.
Inspiration: Wanting turns to involve more than one meaningful click; existing OFFHAND slot and two-handed lock (shipped in spell system foundation) already gate equipment this way passively — this makes that gating actionable rather than just stat-modifying.
Status: worth exploring

---

**Idea:** Elemental caster kits — a comparable matrix
**Added:** 2026-06-28
**Notes:** The Pyromancer (fire) establishes a repeatable kit template that should be mirrored across elements so they balance against each other like-for-like: a caster **weapon** with a three-attack shape (*charge-up → single AOE blast → DoT/control AOE*), one **signature status**, a **utility/defensive spell**, and a **glass-cannon-ish class** that starts with it. Building each element to the same skeleton means tuning one and copying the deltas instead of balancing every kit from scratch.
Draft elements:
- **Fire** *(shipped 2026-06-28, see [[daily/2026-06-28]])* — `burn` DoT; Pyre Scepter (Kindle / Flameburst / Immolate) + Flicker dodge + Pyromancer class.
- **Frost** — `chill` (AGI down; freeze/skip-turn at high stacks); control-leaning, tankier class. Utility: barrier or slow.
- **Storm / Lightning** — chain-hit attacks that arc between enemies; `shock` (target takes +X% damage); high-variance burst. Utility: haste / extra action.
- **Stone / Earth** — `barrier` absorb; DEF-scaling "bruiser caster," slow but durable. Utility: taunt / guard.
- **Blight** — leans on existing `poison` / `bleed`; an attrition class that *wants* long fights (counterpoint to burst). Utility: spread / transfer DoT.
- **Radiant** — heal + smite hybrid, bonus vs undead (ties into the world lore / Forgotten Entity thread). Utility: cleanse.
Each element's signature status is the balance anchor — see the status-vocabulary entry below. Connects to the Identity/Expression arc in **Run Structure & Act Progression** (gear that combos with a spell is the Act 2 hook).
**Status:** `worth exploring`

---

**Idea:** Status-effect vocabulary expansion
**Added:** 2026-06-28
**Notes:** Combat depth and balance both rest on the set of status "verbs" available. Current roster: `poison`, `bleed`, `stun`, `regen`, `burn`. The Effect System v2 / `StatusData` pipeline already supports `stat_modifiers`, `on_apply`/`on_tick`/`on_expire`, `prevents_action`, and stack policies, so several of these are authoring-only (no new code):
- **chill** — passive AGI debuff; at N stacks escalate to a freeze (`prevents_action`). Frost signature. *(authoring-only)*
- **weaken** — STR/SPI debuff to soften enemy output. *(authoring-only)*
- **haste** — sustained AGI buff / chance at an extra action (Flicker is the one-off spike; haste is the sustained form). *(authoring-only)*
- **shock / vulnerable** — target takes +X% damage. Needs a damage-amp hook — check whether `take_damage`/`DamageEffect` can read a multiplier status. *(likely needs code)*
- **barrier / shield** — flat absorb pool consumed before HP; not expressible as a `stat_modifier`. *(needs code)*
- **mark** — next hit auto-crits / bonus-damages a target; pairs with the "first attack deals Nx" proc noted under the Patron Saint entry. *(needs code)*
The authoring-only vs needs-code split is itself useful triage. See [[design.md]] Effect System v2.
**Status:** `worth exploring`

---

**Idea:** Elemental combo reactions
**Added:** 2026-06-28
**Notes:** Let statuses interact so builds emerge from *sequencing*, not just stacking — the mechanical payoff of the Act 3 "Expression" phase in **Run Structure & Act Progression**. Examples: a frost hit on a `burn`ing target triggers a thermal-shock burst (consume both, deal a chunk); a `shock`ed target hit by frost/water chains harder; a "rupture" attack detonates accumulated `poison`/`bleed` stacks for instant damage. Needs a reaction hook — on status apply, check the target's existing statuses for a matching pair and fire a reaction effect. Big lever, but adds combat complexity; gate it behind the base elemental kits + statuses landing first. Risk: balloons into a Genshin-style reaction table — keep the first pass to 2–3 hand-picked reactions.
**Status:** `raw`

---

**Idea:** Sparring-partner enemy archetypes (for balance testing)
**Added:** 2026-06-28
**Notes:** Trial-and-error balance needs enemies that *exercise* specific mechanics, not just stat blocks. A small purpose-built roster doubles as a tuning harness and as real content; each archetype maps to a stat axis, so it also serves as a legibility check (if a DEF build can't survive the glass cannon, DEF is undervalued):
- **Glass cannon** — high damage, low HP/DEF; punishes no-defense builds, rewards stuns/burst/dodge.
- **DoT-immune brute** — high HP, ignores poison/burn/bleed; forces direct damage, counters pure attrition.
- **Buffer / support** — buffs allies or shields itself; makes the player value `weaken`, stuns, and priority targeting (the "respond to enemy intent" goal in **Combat Feel & Pacing**).
- **Evasive skirmisher** — high AGI, hard to hit; rewards accuracy / `mark` and AOE that doesn't rely on landing single hits.
- **Enrager / wind-up** — telegraphs a big hit over several turns (the brace-before-the-hit decision from **Combat Feel & Pacing**).
Enemy authoring isn't in the content editor yet (see "Content editor — enemy and event authoring support"), so these would be hand-written `.tres` for now.
**Status:** `worth exploring`

---

**Idea:** Balance legibility baseline (stat → effect budget)
**Added:** 2026-06-28
**Notes:** Before trial-and-error tuning can converge, the numbers need to be *legible* — there's currently no answer to "what is 1 point of SPI worth?" or "how much should a tier-1 weapon hit for?" Capture a reference (candidate: `journal/detailed/balance.md`) pinning down: how each stat converts to its outputs (CON→max HP, SPI→mana + spell scaling, AGI→hit/dodge, DEF→mitigation, STR→melee, LCK→crit/wildcard), the target combat length (5–8 player turns, per **Combat Feel & Pacing**), the expected player stat/HP curve per act (per **Run Structure & Act Progression**), and a rough power budget per item tier so "this feels off" becomes "this is 2× budget." Doesn't lock anything down — it's a yardstick so playtests produce decisions instead of vibes. First step: audit the actual formulas in code (`take_damage`, max-health / max-mana derivation, any hit/dodge roll) and write down what they currently *are*. See [[detailed/character.md]].
**Status:** `worth exploring`

---

**Idea:** Attack & weapon clarity (tooltips + equipment descriptions)
**Added:** 2026-06-21
**Notes:** There's currently no way to learn what an attack does without already knowing it from the code — picking "Assassinate" off the action list doesn't say what it does or who it targets. Two related UI surfaces: (1) in-combat tooltips on action buttons, showing effect and target type before committing to a turn; (2) a weapon description in the inventory/equip screen listing the attacks it grants, so gear choices are informed by actual combat behavior, not just stat deltas. Both point at the same underlying gap: attacks and weapons need a player-facing description, not just internal effect data.
**Status:** `worth exploring`

---

**Idea:** Character Creation Layers — Background + Patron Saint
**Added:** 2026-05-30
**Notes:**
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

**Status:** `partially done` — see [[design.md]] and [[daily/2026-06-07]].
**Shipped (Phase 1, 2026-06-07):** `BackgroundData` + `PatronSaintData` (+ `lineage_id` on `BlessingData`), player integration (`_setup_background`/`_setup_patron`, gold-reward/shop multipliers), content-editor authoring, hand-built 4-step wizard UI, sample content. Saints ship at tier 1, fully playable; `ascend_patron()` and `_patron_tier_index` are in place.
**Remaining (Phase 2):** shrine/altar ascension event type and the "act" concept it needs; the "first attack deals Nx damage" proc needs a new effect type. Parked/v2: branching saint evolutions, non-combat saints.

---

**Idea:** Content editor — enemy and event authoring support
**Added:** 2026-05-21
**Notes:**
The tool currently covers equipment, attacks, effects, blessings, and classes. Enemies and events are the other major authoring surface — making a new enemy means setting stats, AI behavior, drops, and wiring it into an event; making a new event means defining waves, rewards, and any special scripting. Both involve enough cross-resource wiring that the inspector is genuinely painful. Adding them to the content editor would let the full encounter design loop (enemy stats → event composition → shop/reward tuning) happen outside Godot.
**Status:** `partially done`.
**Shipped:** event authoring — `EventEditor` with per-type forms (Combat / Dialogue / SkillCheck / Rest) via the `.tres`-wraps-JSON wrapper pattern (see [[design.md]] "Events exposed in content editor", 2026-05-22).
**Remaining:** enemy authoring — there is no dedicated enemy editor; enemies are only referenced inside `CombatEventForm`. Need a form for stats, AI behavior, and drops.

---

**Idea:** Content editor — inline sub-resource creation from dropdown
**Added:** 2026-05-21
**Notes:**
When a field expects a resource ref (e.g. a weapon's `attacks` array, or an attack's `effects` array), the dropdown currently only lets you pick an existing file. The missing flow is: click "new" in that dropdown, choose the concrete type (e.g. `AttackData`, `DamageEffect`), give it a name/path, and it's created and immediately wired in. Pairs naturally with a breadcrumb bar — if you're authoring a weapon and create a new attack inline, you should be able to navigate into that attack's form, then navigate back up to the weapon. Without the breadcrumb, you'd have to find the new file in the sidebar to finish filling it in, which breaks the authoring flow for a weapon that needs two or three new attacks at once.
**Status:** `worth exploring`

---

<!-- Add ideas below, newest first -->

**Idea:** Combat Feel & Pacing
**Added:** 2026-05-15
**Notes:**
A single combat encounter should last 5–8 player turns. Encounters are designed to be taxing but winnable — the real difficulty is attrition across a full dungeon, not any single fight. Early dungeons are forgiving warm-ups where misplay is required to be in real danger. Later dungeons force the player to weigh fighting vs resting.

Death should feel like education, not punishment. The player should leave a failed run understanding what they didn't know — a new enemy mechanic, an interaction they hadn't seen — and feel like they can prepare better next time. Enemies have consistent, learnable patterns. Visible states (wind-up animations, status icons) telegraph intent without explicitly showing next-turn damage like Slay the Spire. The player learns what those states mean through experience.

Health is a primary resource, not a buffer. Healing is scarce and deliberate. The tension across a dungeon is "do I have enough left for what comes next," not just "can I win this fight."

Each combat turn should require meaningful decisions informed by enemy state. Weapons and spells have intent. Smart play means responding to what the enemy is setting up — bracing before a big hit, swinging when the enemy is in setup, targeting priority threats.

Enemy HP and active buffs/debuffs are visible. Hidden information is not part of the tension — readable enemies that surprise through new mechanics is.

**Status:** `worth exploring`

---

**Idea:** Run Structure & Act Progression
**Added:** 2026-05-15
**Notes:**
A full run targets 1–1.5 hours. Runs should feel meaningfully different — class unlocks, boons, spells, and loot variety ensure that even the same starting loadout doesn't produce the same run twice.

The emotional arc follows three acts:

**Act 1 — Survival.** The player enters with a vague plan seeded by their class and starting boon. Gear is generalist: raw DEF, HP, basic damage. The player is asking "can I stay alive" not "what am I building." Enemy patterns are simple and teachable. The boon is the only real build signal.

**Act 2 — Identity.** The player finds one or two pieces specific to a build direction and starts making cuts — dropping generalist gear for things that fit. Gear has a type: a weapon that combos with a spell, armor that rewards a playstyle. Higher tier gear has passive or active features that multiply power. Enemy complexity ramps here. Synergies start clicking, the game opens up, and smart decisions need to align with the emerging build.

**Act 3 — Expression.** The player knows what they're building. Gear has multiple interacting properties. Play is about fine-tuning and pruning — knowing when *not* to equip something even if raw stats are better. Enemy design can be more exotic because the player has real tools to respond creatively. Smart play matters most here.

Each act is balanced independently against what the player *should* have at that stage. Act 1 enemies are tuned against a generalist loadout. Act 3 enemies assume real synergies exist.

**Status:** `worth exploring`

---

**Idea:** Spell Casting System
**Added:** 2026-05-06
**Notes:**
Full magic system built around learned spells, mana, and casting equipment. Brainstormed in full — decisions are fairly settled, this is ready to move toward planning.

**Mana** is a second resource derived from SPIRIT the same way max health derives from CON. Fully restored between world map nodes, no regen during a dungeon node. Players ration mana across all encounters in a run.

**Learned spells** form a persistent roster. From that roster the player prepares a limited active subset before entering a dungeon. **Prep slots** are a flat integer on the player, set by class base (like `starting_consumable_slots` on `PlayerClassData`) and increased by equipment modifiers. Cantrips are just spells with `mana_cost = 0` — no special flag needed.

**Innate weapon spells** are defined directly on a staff or spellbook `WeaponData`, registered into the player action list on equip like normal weapon attacks. They bypass prep slots entirely and append to the prepared list.

A new **OFFHAND slot** is added to `Enums.Slot`. It can hold a shield, a casting focus (orb/tome/catalyst), or be left empty. Two-handed weapons lock the offhand using the existing dungeon lock pattern. Spellcasting is not hard-locked by class — any class can equip a focus and cast. The economy enforces specialization naturally: low SPIRIT means low mana and few slots. A warrior who finds a focus with a good innate cantrip gets real hybrid value with no friction.

**Tomes** are a third item type (`TomeData extends EquipmentData`) that teach spells. They live in the bag as ordinary items — clicking a tome in the bag consumes it and learns its spell (the hover detail shows "Teaches: <spell>"); there is no separate tome section. They have gold value for any class. Learning is blocked by the dungeon lock — you can't study mid-dungeon — because it routes through the dungeon-locked bag. Exception: the **sanctified room**, a rare dungeon event that lifts the inventory lock temporarily (already supported via `allows_inventory = true` on the base `Event` class).

**Loot pools** use explicit class tags on each `EquipmentData` (array of class affinities, plus a universal tag for gear that always appears). Two pools at drop time: primary is class-aligned gear, secondary is off-class gear for selling or surprise hybrid builds. Ratio is a tuning lever, roughly 70/30. Stat-weighted rolling was considered but explicit tags were preferred for authorial control and handcrafted intent.

**Status:** `partially done` — foundation shipped 2026-05-08, see [[design.md]] "Spell casting system — foundation design" and [[daily/2026-05-08]].
**Shipped:** mana resource (`max_mana = effective_SPI × mana_modifier + class_mana_bonus`), `SpellData` registered as player actions through `execute_action`/targeting, `OFFHAND` slot, prep slots (mirrors the consumable belt), innate weapon spells, `spell_cost_multiplier` on `EquipmentData`, mage armor via `BlessingData.stat_modifiers`.
**Remaining:** tomes (`TomeData`) + learn UI, class-affinity loot tags + dual-pool drops, the two-handed offhand lock, spell animations, and prep-UI polish (the `InventoryPanel` prep UI is dynamic/unpolished).

---

**Idea:** MCP server for AI-assisted content authoring

**Added:** 2026-06-28

**Notes:** Wrap the existing content editor sidecar as an MCP server so an AI agent can generate game content from natural language ideas. The sidecar already has read/write/list endpoints and the Godot headless round-trip — MCP would just be a tool layer on top. Agent gets schema.json + directory conventions in its system prompt so it can derive file paths deterministically before writing. Ext_resource chaining is solved by bottom-up sequencing: agent creates leaf resources first (effects, attacks), captures their paths, then writes the parent (weapon) referencing them. No new infrastructure needed beyond the MCP transport layer and a system prompt that codifies what the frontend already knows implicitly (where each resource type lives). Likely lives as an additional process alongside the sidecar, or a plugin within it. Tools needed at minimum: list_resources, read_resource, write_resource, get_schema. Linter already exists on write — agent gets validation feedback for free.

**Built (2026-06-28):** Standalone stdio MCP server at `tools/content_editor/sidecar/src/mcp.ts` (official MCP TS SDK + zod), reusing the sidecar's core modules directly — no HTTP hop, web sidecar not required. 11 tools: `get_schema`, `list_resources`, `read_resource`, `write_resource` (reads back + lints), `lint_resource`, `list_assets`, `list_references`, `read_event`/`write_event`, `read_dialogue`/`write_dialogue`. Conventions codified in `tools/content_editor/docs/mcp-authoring.md`, surfaced as the server `instructions` and a readable MCP resource. Registered via repo-root `.mcp.json`; `make mcp` runs it standalone. Smoke-tested with an SDK client (list/read/write/lint) and `make verify` (106/0). Open follow-up: the existing linter only flags dangling `uid://` refs, not `__ref` paths pointing at non-existent files (see `getEntry()` in `resource-index.ts`) — agents must verify ref targets exist first; a disk-existence check would close the gap.

Status: partially done

---

**Idea:** World lore — the Forgotten Entity and the war
**Added:** 2026-04-20
**Notes:** The bad air has a source: a dormant entity, forgotten by name, that was awakened by the scale of death from a regional war fought between major powers. The war killed soldiers and civilians indiscriminately; mass death without religious rites is what fed or triggered the awakening. The entity wasn't summoned — it starved into dormancy long ago, and the war was the meal that woke it. Knowledge of it once existed (priests built shrines for reasons they no longer understood — ritual abstracted the original purpose), but that knowledge was lost or suppressed. The bad air *is* the entity's influence spreading outward. Unconsecrated sites fell first — charnel grounds, plague pits, battlefield graves. Consecrated sites like the catacombs are holding, but the entity is pressing against them; some shrines may already be failing or corrupted on deeper floors. The player arrives mid-escalation: containment is still possible but not guaranteed. Design implications: dungeon difficulty can track proximity to the entity's influence (unconsecrated = already claimed, catacombs = contested frontier); shrine reliability could degrade over run progression as a late-game pressure; charnel ground dungeons could feature risen dead from *both* factions still in opposing armor, with loot from either side. The entity stays unnamed and unexplained for now — "forgotten" is the horror.
**Status:** `worth exploring`

---

**Idea:** Dungeon types and naming
**Added:** 2026-04-20
**Notes:** Different dungeon types carry different lore weight and mechanical pressure. Draft taxonomy (shrine count tracks religious intent at time of burial, not floor length): **Catacombs** — longest, most undead, most shrines; priests consecrated these heavily because faith compelled it, not because they understood the threat; multiple safe rooms throughout; hardest but most protected. **Ossuary** — bone storage, less devout than catacombs; shorter, fewer shrines. **Undercroft** — beneath a church or manor, not fully religious; medium length, one shrine at best. **Vault** — noble family burial, secular; compact, no shrines, unprotected. **Plague pit** — mass burial, no rites; short, unstable, zero shrines; not easy despite being short. **Charnel ground** — battlefield dead from the war, unclaimed; chaotic layout, fast and brutal; no consecration; dead from both factions still in opposing armor. The pattern: places where the church *cared* have shrines; places where nobody did have none. Charnel grounds are especially interesting — they're where the entity woke up first.
**Status:** `worth exploring`

---

**Idea:** Equipment locked in dungeons ("bad air")
**Added:** 2026-04-20
**Notes:** Players cannot equip or unequip *equipment* (armor, weapons, rings) while inside a dungeon — those decisions are locked to safe nodes between runs, rest sites, and shops. Lore: the bad air means concentrating long enough to swap armor is impossible. Identify items on pickup so the player always knows what's in the bag. Calibrate loot drops toward the next floor or run broadly, so finds feel like future rewards rather than taunts. Consecrated rooms (shrines) in longer dungeons act as safe rooms where the bad air doesn't reach — equip swaps are allowed there. **Consumables follow different rules** (see below): they can be picked up mid-dungeon and handled freely at the point of pickup, but the bag is sealed once something is inside. Dungeon types affect pressure: short floors have no shrine, long floors (e.g. catacombs) have several.
**Status:** `partially done`.
**Shipped:** the core equip lock — `_dungeon_locked` in `inventory_panel.gd` disables equip/unequip inside a dungeon; `allows_inventory` on the base `Event` exists for shrine-style exceptions.
**Remaining:** identify-on-pickup, the consecrated-room equip window actually wired to a shrine event, loot calibration toward the next floor, and the consumable directional rules (own entry below).

---

**Idea:** Consumable handling mid-dungeon ("only the dead remain still")
**Added:** 2026-04-20
**Notes:** Consumables have more freedom than equipment mid-dungeon, but still follow a directional rule. At the point of pickup the player can: (1) equip it to an empty belt slot, (2) swap it with an already-equipped consumable — the displaced item goes to the bag or is dropped, player chooses — or (3) put it in the bag. Once something is in the bag mid-dungeon, it stays there; the player cannot retrieve it to the belt. Lore: *"only the dead remain still"* — quick-swapping a vial from hand to belt is motion; rummaging through the bag is staying still, which is a bad omen in bad air. Design consequence: "put it in the bag" is a real commitment, not a neutral choice — it locks the item away until the dungeon is cleared. A full belt with a pickup creates genuine tension: swap (losing access to the old item) or bag (losing access to the new one). Rewards leaving belt slots open before descending as a form of preparation.
**Status:** `worth exploring`

---

**Idea:** "Bad air" as a lore thread
**Added:** 2026-04-20
**Notes:** The equipment-lock mechanic surfaces a broader lore question: what *is* the bad air? Implies the undead (or what controls them) have an active, spreading presence — not just set dressing. Could be seeded through shrine text, item flavor text, NPC warnings before a run, or environmental details. No codex dump needed; sprinkle it. The bad-air framing also opens space for environmental hazards, resistances, or consumables tied to that fiction (e.g., incense that wards bad air, giving a brief equip window). Parking as a worldbuilding thread to develop alongside dungeon content.
**Status:** `worth exploring`

---

**Idea:** Consumable belt growth mechanics
**Added:** 2026-04-20
**Notes:** MVP ships with a fixed `starting_consumable_slots` per class and a `Inventory.set_belt_size()` helper. Expansion mechanic is deferred. Two plausible directions: (a) specific equipment (e.g., a utility belt item) grants `+N` belt slots via a new `bonus_consumable_slots` field on `EquipmentData`, composable with the existing stat-modifier layer; (b) level-up or milestone rewards unlock a slot at certain levels. Infrastructure is already in place — just needs a source-of-truth for the delta and a call into `set_belt_size()`.
**Status:** `worth exploring`

---

**Idea:** Status-effect consumables (cure / remove)
**Added:** 2026-04-20
**Notes:** Add a `CURE` variant to `ConsumableData.Effect` once a status-effect system exists. Depends on: statuses being a first-class player state (poison, bleed, stun), and the dispatcher in `game.gd` knowing how to clear them. Parking until statuses ship.
**Update (2026-06-21):** the blocking dependency is met — statuses are now first-class via Effect System v2 (`StatusData`, `apply_status`/`remove_status`, see [[design.md]] 2026-05-02). This is now actionable: a cure consumable would be a new `Effect` subclass that calls `remove_status` by tag, authored as a `.tres` and dropped into `ConsumableData.effects` (no enum needed under the unified Effect pipeline).
**Status:** `worth exploring`

---

**Idea:** Group dialogue UI components in a shared container
**Added:** 2026-03-25
**Notes:** Instead of placing dialogue UI nodes individually, wrap them in a container so they scale together as a unit. Makes it easier to maintain consistent proportions when adjusting resolution or layout.
**Status:** `worth exploring`

---

**Idea:** Roguelike Run Structure
**Added:** 2026-02-22
**Notes:**
Core gameplay loop is run-based — the player descends through a dungeon, completes a run, then starts fresh. No persistent world between runs (or very minimal persistence TBD).

**Run structure:**
- A run is made up of several floors in sequence
- Each floor escalates in difficulty
- Each floor has a theme (e.g. crypt, sewers, forest depths, volcanic caves) — theme affects encounter types, enemy roster, environmental hazards, and possibly music/visuals
- End of a run = boss floor or escape condition TBD

**Encounter types per floor:**
- **Combat** — turn-based or real-time fights against enemies; core of most floors
- **Skill checks** — stat-based challenges (STR to force a door, AGI to squeeze through, SPI to sense a curse, LCK as a wildcard)
- **Loot** — treasure rooms, hidden caches, chests with risk/reward
- **Roleplay events** — text-based decision nodes; outcomes affect the current run (buffs, debuffs, story flavor, resource gain/loss)
- Possibly more types later: merchants, shrines, traps, rest sites

**Design principles to carry forward:**
- Keep it simple first — nail one floor with a handful of encounter types before expanding
- The stat and equipment systems should integrate naturally into skill checks and combat without special-casing
- Floor themes are a content/data concern; the underlying systems should be theme-agnostic
- Enemy difficulty scaling should be data-driven so floors can be tuned without code changes

**Long-term directions (not for now):**
- Multiple floor themes with curated encounter pools per theme
- Meta-progression between runs (unlocks, permanent upgrades)
- Branching floor paths — player chooses next floor theme
- Run modifiers or curses that persist across a whole run

**Status:** `worth exploring`

