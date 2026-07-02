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
| `make mcp` | Run the MCP server on stdio (for manual testing via an MCP inspector) |
| `make schema` | Re-export `schema.json` from Godot after GDScript class changes (requires Godot; override with `GODOT_BIN=/path/to/godot`) |
| `make verify` | Round-trip parse/serialise every `.tres` in `resources/` to check for structural diffs |

**Usage**

For a full reference covering every screen and resource type, see the
[Content Editor User Guide](tools/content_editor/docs/USER_GUIDE.md).

#### Authoring content with an AI agent (MCP)

The same sidecar core is exposed as a stdio **MCP server** so an AI agent
(Claude Code, Claude Desktop) can list, read, and write content resources
directly — with linter feedback on every write. It reuses the native `.tres`
parser, so **Godot does not need to be running** and the web editor above does
**not** need to be up.

A repo-root `.mcp.json` registers the server, so **Claude Code in this repo
discovers it automatically** — just start a session and the `crawler-content`
tools appear. For Claude Desktop, add an equivalent entry pointing at
`tools/content_editor/sidecar/src/mcp.ts` (see the conventions doc below).

The server provides tools for both `.tres` resources (`get_schema`,
`list_resources`, `read_resource`, `write_resource`, `lint_resource`,
`list_assets`, `list_references`) and the JSON content types (`read_event` /
`write_event`, `read_dialogue` / `write_dialogue`). The recommended agent flow —
inspect the schema, read an existing sibling to learn the envelope shape, then
build leaf resources before the parent that references them — plus the directory
map and JSON envelope encodings are documented in
[MCP Authoring Conventions](tools/content_editor/docs/mcp-authoring.md). That doc
is also served to the agent as the MCP server's instructions and as a readable
resource, so it is available in-session without being pasted in.

Run `npm install` in `tools/content_editor/` once so the MCP SDK is installed.
`make mcp` runs the server standalone for manual testing (e.g. with
`npx @modelcontextprotocol/inspector`).

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
