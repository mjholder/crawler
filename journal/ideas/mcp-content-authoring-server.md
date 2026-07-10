# MCP server for AI-assisted content authoring

**Added:** 2026-06-28
**Summary:** Wrap the content-editor sidecar as an MCP server so an AI agent can author game content from natural-language ideas.

## Notes
Wrap the existing content editor sidecar as an MCP server so an AI agent can generate game content from natural language ideas. The sidecar already has read/write/list endpoints and the Godot headless round-trip — MCP would just be a tool layer on top. Agent gets schema.json + directory conventions in its system prompt so it can derive file paths deterministically before writing. Ext_resource chaining is solved by bottom-up sequencing: agent creates leaf resources first (effects, attacks), captures their paths, then writes the parent (weapon) referencing them. No new infrastructure needed beyond the MCP transport layer and a system prompt that codifies what the frontend already knows implicitly (where each resource type lives). Likely lives as an additional process alongside the sidecar, or a plugin within it. Tools needed at minimum: list_resources, read_resource, write_resource, get_schema. Linter already exists on write — agent gets validation feedback for free.

## Shipped
**Built (2026-06-28):** Standalone stdio MCP server at `tools/content_editor/sidecar/src/mcp.ts` (official MCP TS SDK + zod), reusing the sidecar's core modules directly — no HTTP hop, web sidecar not required. 11 tools: `get_schema`, `list_resources`, `read_resource`, `write_resource` (reads back + lints), `lint_resource`, `list_assets`, `list_references`, `read_event`/`write_event`, `read_dialogue`/`write_dialogue`. Conventions codified in `tools/content_editor/docs/mcp-authoring.md`, surfaced as the server `instructions` and a readable MCP resource. Registered via repo-root `.mcp.json`; `make mcp` runs it standalone. Smoke-tested with an SDK client (list/read/write/lint) and `make verify` (106/0).

## Remaining
- The existing linter only flags dangling `uid://` refs, not `__ref` paths pointing at non-existent files (see `getEntry()` in `resource-index.ts`) — agents must verify ref targets exist first; a disk-existence check would close the gap.
