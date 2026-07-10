# Crawler — Developer Journal

A running log of development on this Godot 4 project.

## Structure

```
journal/
├── README.md          # This file
├── daily/
│   ├── TEMPLATE.md    # Copy this for each new session
│   └── YYYY-MM-DD.md  # One file per session
├── design.md          # Design decisions and rationale
├── ideas-board.md     # Kanban backlog (Obsidian Kanban plugin)
├── ideas/             # Per-idea docs, one file per card
│   └── TEMPLATE.md
└── ideas-archive.md   # Resolved ideas (shipped / dropped), kept for history
```

The active backlog is the [[ideas-board.md]] Kanban board plus the `ideas/` docs it
links to; see [[detailed/kanban-workflow.md]] for the format and conventions. The old
flat `ideas.md` was fully migrated onto the board (2026-07-10) and removed;
[[ideas-archive.md]] holds resolved ideas for history.

## Workflow

1. Copy [[daily/TEMPLATE.md]] to a new `daily/YYYY-MM-DD.md`
2. Fill it in during or after your session
3. Upload to the Claude project for context in future conversations

## Tips for Claude uploads

- Each daily entry is designed to be self-contained
- Upload [[design.md]], [[ideas-board.md]] (and the `ideas/` docs) alongside dailies for full context
- The more honest the blockers/notes sections, the more useful the AI context
