# Kanban Backlog Workflow

**Date:** 2026-07-10
**Status:** v1 — locked (confirmed against a real Obsidian save)

## Overview

The backlog lives on an Obsidian Kanban board, [[ideas-board.md]] (plugin
`obsidian-kanban` v2.0.51), backed by a directory of per-idea docs in `journal/ideas/`.
This **replaced** the single-file `ideas.md`, which was fully migrated onto the board on
2026-07-10 and removed. [[ideas-archive.md]] holds resolved (shipped / dropped) ideas for
history.

The board is plain markdown that the plugin re-reads and re-serializes, so both the
Obsidian UI and hand-edits (by a human or Claude) are valid ways to change it, as long
as edits match the serialization format.

## Card model

- The **bulk of an idea lives in its own doc**, `journal/ideas/<slug>.md`, created from
  [[ideas/TEMPLATE.md]]. Filename slug is kebab-case.
- A **card** is one line: `- [ ] <Title> — <one-line summary> [[ideas/<slug>]]`.
- The idea doc does **not** carry a status field. The board lane is the single source of
  truth for status, so there's nothing to keep in sync.
- Each idea doc is its own wikilink target, preserving the Obsidian graph that
  [[design.md]] and the daily logs rely on.

## Lanes

Four lanes, left to right:

| Lane | Meaning |
|---|---|
| `Backlog` | Captured, not started. Raw thoughts and "worth exploring" ideas. |
| `In Progress` | Actively being designed or built. |
| `In Review` | Foundation shipped, awaiting verification / balance / content authoring. |
| `Done` | Shipped and closed. (Marked as the plugin's "complete" lane.) |

### Status mapping (used for the 2026-07-10 ideas.md migration)

The old `ideas.md` `**Status:**` vocabulary mapped onto lanes as follows (kept as a
record of how the migration was reconciled — each entry's lane was verified against its
actual shipped state, not just its stale status line):

- `raw`, `worth exploring` → **Backlog**
- `moved to plan`, actively building → **In Progress**
- `partially done` (shipped systems, work remaining) → **In Review**
- `completed` → **Done** (and later archived to [[ideas-archive.md]])
- `shelved` / `abandoned` → left off the board (stays in [[ideas-archive.md]])

## How Claude edits the board

These are plain-text markdown operations — no Godot, no running Obsidian:

- **Add a card:** insert a `- [ ] <Title> — <summary> [[ideas/<slug>]]` line under the
  target `## Lane` heading, above the `%% kanban:settings %%` footer. New captures go
  under `## Backlog`.
- **Move a card:** cut the card's line from its current lane and paste it under the
  destination lane's heading. Moving to `Done` = shipped/closed.
- **Read board state:** parse `## <Lane>` headings and the `- [ ]` lines beneath each.
- Always match the canonical format exactly so an Obsidian re-save produces no diff.

## Canonical format

Confirmed 2026-07-10 by round-tripping the seed through Obsidian (created a card, moved it
between lanes, saved). Findings:

- **Lanes** are `## <Lane Name>` H2 headings; **cards** are `- [ ] <text>` list items.
  Obsidian left the hand-authored card line byte-for-byte unchanged — so the
  `- [ ] <Title> — <summary> [[ideas/<slug>]]` format is safe.
- **Moving a card** just relocates its `- [ ]` line under the destination lane's heading.
- **Whitespace** is cosmetic — the plugin pads lanes with blank lines but tolerates
  single blank lines in hand-edits and round-trips them without complaint.
- **Settings footer** stays minimal (`{"kanban-plugin":"board"}`) until you toggle board
  options in the UI. There is **no `**Complete**` marker** under `Done` yet — that only
  appears if you mark `Done` as a "complete" lane in the UI. Optional; not required for
  the workflow. If added later, record its exact placement here.

Format as it stands (matches [[ideas-board.md]]):

````
---

kanban-plugin: board

---

## Backlog

- [ ] Example idea — one-line summary [[ideas/example-idea]]


## In Progress


## In Review


## Done


%% kanban:settings
```
{"kanban-plugin":"board"}
```
%%
````

Once confirmed, update the "Status" line at the top to `v1 — locked`.
