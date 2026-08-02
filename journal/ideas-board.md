---

kanban-plugin: board

---

## Backlog

- [ ] Player Class Roster — 10-class stat-coverage matrix — A 10-class roster giving every stat a build-focus anchor, to unblock content generation and give the balance pass a finite target. [[ideas/player-class-roster]]
- [ ] Elemental Caster Kits — a Comparable Matrix — Mirror the Pyromancer kit skeleton (weapon + signature status + utility spell + class) across elements so they balance like-for-like. [[ideas/elemental-caster-kits]]
- [ ] Content editor — inline sub-resource creation — Let a resource-ref dropdown create a new concrete sub-resource inline and wire it in, with breadcrumb navigation. [[ideas/content-editor-inline-subresource-creation]]
- [ ] Dungeon types and naming — Lore-weighted dungeon taxonomy (catacombs, ossuary, undercroft, vault, plague pit, charnel ground) where shrine count tracks burial piety. [[ideas/dungeon-types-and-naming]]
- [ ] Consumable belt growth mechanics — Grow the consumable belt past its per-class starting size via equipment slots or level-up milestones. [[ideas/consumable-belt-growth]]
- [ ] Status-effect consumables (cure / remove) — A cure/remove-status consumable, now unblocked by Effect System v2 — authored as an Effect .tres calling remove_status. [[ideas/status-effect-consumables]]
- [ ] Group dialogue UI components in a shared container — Wrap dialogue UI nodes in a shared layout container so they scale together. [[ideas/group-dialogue-ui-container]]
- [ ] Mana as Capacity — SPI Gates, Tomes Carry Potency — SPI sets mana capacity (casts/floor), not spell damage — spells carry flat authored power; martial power scales with stats, caster power scales with content. [[ideas/mana-as-capacity]]
- [ ] Weapon Anatomy — Power and Scaling as Two Tunable Axes — Split weapon damage into flat `power` and stat `scaling` on `WeaponData`; smithing only moves power, rarity only moves scaling. [[ideas/weapon-anatomy-power-and-scaling]]
- [ ] Equipment Tags and Riders — Two Kinds of Rarity Payload — Numeric TAGS (rolled, compose with power/scaling) vs. binary RIDERS (rarity-gated, never on commons) so higher tiers gain new behavior, not just bigger numbers. [[ideas/equipment-tags-and-riders]]


## In Progress

- [ ] Player-facing information & combat legibility — Surface what attacks/weapons/statuses/procs actually do: tooltips, gear descriptions, proc/self-cost visibility, damage-formula/scaling-stat legibility, and damage-source feedback. [[ideas/player-facing-legibility]]
- [ ] Status-Effect Vocabulary Expansion — Grow the status "verb" roster (chill, weaken, haste, shock, barrier, mark), triaged by authoring-only vs. needs-code. [[ideas/status-effect-vocabulary]]


## In Review



## Done

- [ ] Martial utility verbs — Bleed, Shatter, Brace — Non-magic verb set mirroring the elemental matrix; systems shipped, .tres content and Sentinel kit unauthored. [[ideas/martial-utility-verbs]]
- [ ] Elemental signature identities — Poison, Fire, Lightning, Frost — Concrete mechanics for four elemental signatures; systems shipped, .tres content unauthored. [[ideas/elemental-signature-identities]]
- [ ] Pierce as a percentage split instead of a flat armor reduction — Two-stream ratio split shipped (`floor(amount * pierce)` to HP, remainder to armor) with tooltips + tooling; weapon/enchant pierce-tier authoring and Frost tuning remain. [[ideas/pierce-as-percentage-split]]
- [ ] Roguelike Run Structure — Design pillar: run-based multi-floor descent with themed floors and four core encounter types, kept theme-agnostic and data-driven. [[ideas/roguelike-run-structure]]
- [ ] Consumable handling mid-dungeon — Directional mid-dungeon consumable rules — belt swaps are free, but bagging an item locks it away until the dungeon clears. [[ideas/consumable-handling-mid-dungeon]]
- [ ] Consecutive-attack dodge decay — AGI dodge chance halves per successful dodge within a round, resetting each round; shipped 2026-07-07. [[ideas/consecutive-attack-dodge-decay]]
- [ ] Per-Hand Weapon Restriction + Offhand Moveset — `hand_restriction` enum + per-hand movesets with a hand-selection UI and animated mirrored offhand weapons; shipped 2026-07-03. [[ideas/per-hand-weapon-restriction]]
- [ ] DEF as refreshing ward — Replaces linear DEF mitigation with a per-round armor buffer; shipped as armor, only a balance pass remains. [[ideas/def-refreshing-ward]]
- [ ] MCP server for AI-assisted content authoring — 11-tool stdio server shipped; one linter follow-up (verify `__ref` paths) remains. [[ideas/mcp-content-authoring-server]]
- [ ] Luck — Crit Chance & Loot Quality — LCK/100 linear crit chance that doubles the whole hit (damage + stacks), plus deferred loot-quality scaling; explicitly not dodge. [[ideas/luck-crit-loot-quality]]
- [ ] Attribute Distribution, Leveling & Resource-Stat Economy — Level 1–10 growth curve (primary/secondary/tertiary + free points) targeting primary-stat 100 around Lv8, plus CON/SPI consolidation and cantrip/spell mana costs. [[ideas/attribute-distribution-leveling]]
- [ ] Equipment locked in dungeons ("bad air") — Equip lock shipped; identify-on-pickup, shrine equip window, and loot calibration remain. [[ideas/equipment-locked-in-dungeons]]
- [ ] Spell Casting System — Learned-spell magic with mana, prep slots, foci, tomes; foundation + tomes + offhand lock shipped, dual-pool loot + prep-UI polish remain. [[ideas/spell-casting-system]]
- [ ] Content editor — enemy and event authoring — Events shipped; a dedicated enemy stat/AI/drops editor still remains. [[ideas/content-editor-enemy-event-authoring]]
- [ ] Character Creation Layers — Background + Patron Saint — Three-part build identity with saint tiers that ascend across acts; Phase 1 + shrine/act progression shipped, proc + act maps remain. [[ideas/character-creation-layers]]
- [ ] Run Structure & Act Progression — Design pillar: 1–1.5h runs across three acts (Survival / Identity / Expression), each balanced against expected gear. [[ideas/run-structure-and-act-progression]]
- [ ] Reusable combat-UI widget scenes — Extract code-built combat-UI widgets (attack buttons, consumable belt slots, status icons) into reusable .tscn scenes with their own scripts, following the health_bar.tscn pattern. [[ideas/combat-ui-widget-scenes]]
- [ ] Dual-Action Combat (Mainhand / Offhand) — Split the player turn into two independently-gated per-hand action slots with an explicit End Turn; shipped, HUD layout + v2 anims remain. [[ideas/dual-action-combat]]
- [ ] Enemy Attack Patterns — Optional data-driven fixed-sequence move patterns for enemies, layered over the `_perform_action` hook; sound + weighted extension remain. [[ideas/enemy-attack-patterns]]
- [ ] Status effects clear at combat end — Combat-inflicted statuses wipe at fight end while equipment/background statuses persist; groundwork shipped, dependent status entries remain. [[ideas/status-clear-at-combat-end]]


***

## Archive

- [ ] Elemental Combo Reactions — Let statuses interact so builds emerge from sequencing (e.g. frost-on-burn thermal shock), gated behind base kits landing. [[ideas/elemental-combo-reactions]]
- [ ] Sparring-Partner Enemy Archetypes — A small purpose-built enemy roster, each exercising one stat axis, that doubles as a tuning harness and real content. [[ideas/sparring-partner-enemies]]
- [ ] Combat Feel & Pacing — Design pillar: 5–8-turn attrition-based fights, learnable enemy patterns, health as a primary resource, and readable state. [[ideas/combat-feel-and-pacing]]
- [ ] World lore — the Forgotten Entity and the war — The bad air's source: a dormant, forgotten entity woken by mass war-death; the horror is that it stays unnamed. [[ideas/forgotten-entity-lore]]
- [ ] Balance Legibility Baseline — A reference doc pinning how each stat converts to outputs, target combat length, per-act curves, and item power budgets. [[ideas/balance-legibility-baseline]]
- [ ] "Bad air" as a lore thread — Develop the "bad air" fiction as a sprinkled worldbuilding thread through shrine text, item flavor, and NPC warnings. [[ideas/bad-air-lore-thread]]

%% kanban:settings
```
{"kanban-plugin":"board"}
```
%%