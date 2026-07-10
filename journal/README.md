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
└── ideas.md           # Legacy backlog — being migrated to the board
```

The active backlog is the [[ideas-board.md]] Kanban board plus the `ideas/` docs it
links to; see [[detailed/kanban-workflow.md]] for the format and conventions.
[[ideas.md]] / [[ideas-archive.md]] remain the source of truth for existing entries
until they're migrated onto the board.

## Workflow

1. Copy [[daily/TEMPLATE.md]] to a new `daily/YYYY-MM-DD.md`
2. Fill it in during or after your session
3. Upload to the Claude project for context in future conversations

## Tips for Claude uploads

- Each daily entry is designed to be self-contained
- Upload [[design.md]], [[ideas-board.md]] (and the `ideas/` docs) alongside dailies for full context
- The more honest the blockers/notes sections, the more useful the AI context
