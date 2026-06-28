# Crawler

A turn-based roguelike dungeon crawler built in **Godot 4.6** (GDScript only).
The project is an **early prototype** — the core turn loop exists, while most
systems are still stubs or yet to be built.

## Repository Layout

| Path | Role |
|---|---|
| `scripts/` | GDScript source — turn state machine, player/enemy, equipment, character creation |
| `scenes/` | Godot `.tscn` scene files |
| `assets/` | Raw media — `audio/`, `sprites/` (ui, world_map, paper_doll, enemies, weapons) |
| `resources/` | All `.tres` data resources (equipment, events, world map, effects…) |
| `journal/` | Developer docs — design decisions, architecture map, idea backlog, daily logs |
| `tools/` | Internal tooling (see below) |

The `journal/` directory is the place to understand *why* the code looks the way
it does: `journal/design.md` (architectural decisions), `journal/architecture.md`
(Mermaid diagrams of the code structure), `journal/ideas.md` (future-systems
backlog), and `journal/daily/` (session logs).

## Tools

### Content Editor

A local web app for editing the game's `.tres` content resources — weapons,
armor, events, dialogue, classes, blessings, and more — without opening Godot.
It provides form and table views over every resource type, a dedicated dialogue
editor, an event editor, and a where-used panel for tracking references. It runs
as a Fastify sidecar plus a Vite/React frontend.

**Prerequisites**

- Node.js and npm. Run `npm install` once in `tools/content_editor/` — npm
  workspaces will install both the `sidecar` and `frontend` packages.
- Godot on your `PATH` is only needed for `make schema` (re-exporting the schema
  after changing GDScript class definitions). Normal editing does not require it.

**Quick start**

```sh
cd tools/content_editor
npm install        # first time only
make up
```

Then open <http://localhost:5173>.

**Make targets**

| Command | Description |
|---|---|
| `make up` | Start the editor (sidecar + frontend) at http://localhost:5173 |
| `make down` | Stop all editor processes |
| `make schema` | Re-export `schema.json` from Godot after GDScript class changes (requires Godot; override with `GODOT_BIN=/path/to/godot`) |
| `make verify` | Round-trip parse/serialise every `.tres` in `resources/` to check for structural diffs |

**Usage**

For a full reference covering every screen and resource type, see the
[Content Editor User Guide](tools/content_editor/docs/USER_GUIDE.md).

## Credits

### 3D Models

**Old King Armor**
["Old king armor"](https://skfb.ly/6ZHYU) by Pedro B. Goulart
Licensed under [Creative Commons Attribution 4.0](http://creativecommons.org/licenses/by/4.0/)

**Viking Battle Axe**
["Viking battle axe"](https://skfb.ly/osHG6) by Mikhail Antonov
Licensed under [Creative Commons Attribution 4.0](http://creativecommons.org/licenses/by/4.0/)

**Man**
["Man"](https://skfb.ly/ovLzA) by Pumpkin
Licensed under [Creative Commons Attribution 4.0](http://creativecommons.org/licenses/by/4.0/)

**Skeleton Warrior**
["skeleton_warrior"](https://skfb.ly/pqNA8) by Ron.Edelstein
Licensed under [Creative Commons Attribution 4.0](http://creativecommons.org/licenses/by/4.0/)
