/**
 * Stdio MCP server for AI-assisted content authoring.
 *
 * Wraps the content-editor sidecar's existing core modules (no Godot on the hot
 * path, no HTTP hop) as MCP tools so an AI agent can list / read / write every
 * content type the web editor supports — with linter feedback on every write.
 *
 * Launched by an MCP host (Claude Code / Claude Desktop) over stdio; the web
 * sidecar (server.ts) does NOT need to be running.
 *
 * IMPORTANT: stdout is the JSON-RPC transport.  Several core functions log via
 * console.log (buildIndex, refreshSchema) — we redirect console output to stderr
 * up front so it never corrupts the protocol stream.
 */
console.log = (...args: unknown[]) => console.error(...args);
console.info = (...args: unknown[]) => console.error(...args);

import { readFileSync, writeFileSync, existsSync, readdirSync, statSync } from "node:fs";
import { join, relative, extname } from "node:path";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

import { readResource, writeResource } from "./godot.js";
import { getSchema, getAllProperties, invalidateSchema, type PropDescriptor } from "./schema.js";
import {
  buildIndex,
  listByClassWithSubclasses,
  getEntry,
} from "./resource-index.js";
import { listAssets } from "./asset-index.js";
import { lintResource } from "./linter.js";
import { PROJECT_ROOT } from "./config.js";

// --- Helpers ----------------------------------------------------------------

function absPath(resPath: string): string {
  return join(PROJECT_ROOT, resPath.replace("res://", ""));
}

/** Wrap a JSON-serialisable value as MCP text content. */
function json(value: unknown) {
  return { content: [{ type: "text" as const, text: JSON.stringify(value, null, 2) }] };
}

/** Wrap an error message as an MCP error result. */
function fail(message: string) {
  return { content: [{ type: "text" as const, text: message }], isError: true };
}

function readJsonFile(resPath: string): unknown {
  return JSON.parse(readFileSync(absPath(resPath), "utf8"));
}

function writeJsonFile(resPath: string, data: unknown): void {
  writeFileSync(absPath(resPath), JSON.stringify(data, null, 2), "utf8");
}

/** Collect enum tables referenced by a class's properties. */
function referencedEnums(props: PropDescriptor[]): Record<string, Record<string, number>> {
  const schema = getSchema();
  const out: Record<string, Record<string, number>> = {};
  for (const p of props) {
    for (const name of [p.enum_ref, p.type, p.element_type, p.key_type, p.value_type]) {
      if (name && schema.enums[name]) out[name] = schema.enums[name];
    }
  }
  return out;
}

function walkTres(absDir: string, results: string[]): void {
  for (const entry of readdirSync(absDir)) {
    const abs = join(absDir, entry);
    if (statSync(abs).isDirectory()) walkTres(abs, results);
    else if (entry.endsWith(".tres"))
      results.push("res://" + relative(PROJECT_ROOT, abs).replace(/\\/g, "/"));
  }
}

// Conventions doc — surfaced as the server `instructions` and as a readable resource.
const CONVENTIONS_PATH = join(PROJECT_ROOT, "tools/content_editor/docs/mcp-authoring.md");
const CONVENTIONS = existsSync(CONVENTIONS_PATH)
  ? readFileSync(CONVENTIONS_PATH, "utf8")
  : "Authoring conventions doc not found at tools/content_editor/docs/mcp-authoring.md.";

// --- Server -----------------------------------------------------------------

const server = new McpServer(
  { name: "crawler-content", version: "0.1.0" },
  {
    instructions:
      "Tools to author Godot .tres game resources and JSON events/dialogue for the crawler roguelike. " +
      "Before writing a new resource, call get_schema(class) and read_resource on an existing sibling of the " +
      "same class to learn the exact JSON envelope shape. Create leaf resources (effects, attacks, blessing " +
      "tiers) first, then write the parent referencing them by { \"__ref\": \"res://...\" }. " +
      "The full conventions doc is below.\n\n" +
      CONVENTIONS,
  }
);

// Conventions as a readable MCP resource (re-readable on demand).
server.registerResource(
  "authoring-conventions",
  "doc://crawler/authoring-conventions",
  {
    title: "Crawler content authoring conventions",
    description: "Directory map, JSON envelope format, enums, and the bottom-up authoring workflow.",
    mimeType: "text/markdown",
  },
  async (uri) => ({
    contents: [{ uri: uri.href, mimeType: "text/markdown", text: CONVENTIONS }],
  })
);

// --- Tools ------------------------------------------------------------------

server.registerTool(
  "get_schema",
  {
    title: "Get resource schema",
    description:
      "Return the content schema. With no argument, the full schema (all classes + enums). " +
      "With `class`, that class's flattened property list (following inheritance) plus the enum tables it references.",
    inputSchema: { class: z.string().optional().describe("Script class name, e.g. WeaponData") },
  },
  async ({ class: cls }) => {
    const schema = getSchema();
    if (!cls) return json(schema);
    if (!schema.classes[cls]) return fail(`Unknown class: ${cls}`);
    const properties = getAllProperties(cls, schema);
    return json({ class: cls, script: schema.classes[cls].script, properties, enums: referencedEnums(properties) });
  }
);

server.registerTool(
  "refresh_schema",
  {
    title: "Refresh schema from disk",
    description:
      "Reload schema.json from disk, picking up classes/fields added since the server started (e.g. after " +
      "running `make schema`). No Godot on the hot path — this only re-reads the cached file. Run this if " +
      "get_schema / write_resource reports 'Unknown class' for a class you just added. Returns the class count.",
    inputSchema: {},
  },
  async () => {
    invalidateSchema();
    const schema = getSchema();
    return json({
      ok: true,
      classes: Object.keys(schema.classes).length,
      enums: Object.keys(schema.enums).length,
    });
  }
);

server.registerTool(
  "list_resources",
  {
    title: "List resources",
    description:
      "List existing resource paths, either by script class (includes subclasses) or by directory tree. " +
      "Provide exactly one of `class` or `dir`.",
    inputSchema: {
      class: z.string().optional().describe("Script class name, e.g. WeaponData"),
      dir: z.string().optional().describe("res:// directory, e.g. res://resources/equipment/weapons/"),
    },
  },
  async ({ class: cls, dir }) => {
    if (cls) return json(listByClassWithSubclasses(cls, getSchema()));
    if (dir) {
      const abs = absPath(dir);
      if (!existsSync(abs)) return fail(`dir not found: ${dir}`);
      const results: string[] = [];
      walkTres(abs, results);
      return json(results.sort());
    }
    return fail("Provide either `class` or `dir`.");
  }
);

server.registerTool(
  "read_resource",
  {
    title: "Read resource",
    description:
      "Read a .tres resource and return its JSON envelope. Read a sibling of the class you intend to write " +
      "first — it is the most reliable guide to the exact envelope shape (refs, sub-resources, dict key types).",
    inputSchema: { path: z.string().describe("res:// path to a .tres file") },
  },
  async ({ path }) => {
    try {
      return json(await readResource(path));
    } catch (e) {
      return fail(String(e));
    }
  }
);

server.registerTool(
  "write_resource",
  {
    title: "Write resource",
    description:
      "Create or overwrite a .tres resource. `fields` is the JSON envelope body (everything except _godot_meta, " +
      "which is assembled from `class`). After writing, the resource is read back and linted; the lint array is " +
      "returned. An empty lint array means no dangling refs or bad expressions.",
    inputSchema: {
      path: z.string().describe("res:// destination path, e.g. res://resources/spells/fireball.tres"),
      class: z.string().describe("Script class name, e.g. SpellData"),
      fields: z.record(z.string(), z.unknown()).describe("Envelope body: field name -> value"),
    },
  },
  async ({ path, class: cls, fields }) => {
    const schema = getSchema();
    const desc = schema.classes[cls];
    if (!desc) return fail(`Unknown class: ${cls}`);
    try {
      const envelope = {
        ...fields,
        _godot_meta: { class: cls, script: desc.script, path, inline: false },
      };
      await writeResource(path, envelope);
      buildIndex(); // pick up the new/changed file so refs resolve
      const data = await readResource(path);
      const lint = lintResource(data);
      return json({ ok: true, path, lint });
    } catch (e) {
      return fail(String(e));
    }
  }
);

server.registerTool(
  "lint_resource",
  {
    title: "Lint resource",
    description:
      "Validate a resource without writing it — checks for dangling references and unknown variables in " +
      "expression fields. Provide either `path` (reads from disk) or `data` (a JSON envelope).",
    inputSchema: {
      path: z.string().optional().describe("res:// path to a .tres file"),
      data: z.record(z.string(), z.unknown()).optional().describe("A JSON envelope to lint directly"),
    },
  },
  async ({ path, data }) => {
    try {
      if (path) return json(lintResource(await readResource(path)));
      if (data) return json(lintResource(data));
      return fail("Provide either `path` or `data`.");
    } catch (e) {
      return fail(String(e));
    }
  }
);

server.registerTool(
  "list_assets",
  {
    title: "List assets",
    description:
      "List real asset paths so references point at files that exist. Type is one of " +
      "Texture2D, AudioStream, PackedScene, SpriteFrames.",
    inputSchema: {
      type: z.enum(["Texture2D", "AudioStream", "PackedScene", "SpriteFrames"]).describe("Asset type"),
    },
  },
  async ({ type }) => json(listAssets(type))
);

server.registerTool(
  "list_references",
  {
    title: "List references",
    description:
      "Show a resource's index entry: its UID and which .tres files reference it. Useful before editing or " +
      "deleting a shared resource.",
    inputSchema: { uid_or_path: z.string().describe("A uid:// or res:// identifier") },
  },
  async ({ uid_or_path }) => {
    const entry = getEntry(uid_or_path);
    return entry ? json(entry) : fail(`Not found in index: ${uid_or_path}`);
  }
);

// Events and dialogue are plain JSON files, not .tres.

server.registerTool(
  "read_event",
  {
    title: "Read event JSON",
    description: "Read an event JSON file under resources/events/<type>/.",
    inputSchema: { path: z.string().describe("res:// path to an event .json file") },
  },
  async ({ path }) => {
    try {
      return json(readJsonFile(path));
    } catch (e) {
      return fail(String(e));
    }
  }
);

server.registerTool(
  "write_event",
  {
    title: "Write event JSON",
    description: "Create or overwrite an event JSON file under resources/events/<type>/.",
    inputSchema: {
      path: z.string().describe("res:// path to an event .json file"),
      data: z.record(z.string(), z.unknown()).describe("Event JSON object"),
    },
  },
  async ({ path, data }) => {
    try {
      writeJsonFile(path, data);
      return json({ ok: true, path });
    } catch (e) {
      return fail(String(e));
    }
  }
);

server.registerTool(
  "read_dialogue",
  {
    title: "Read dialogue JSON",
    description: "Read a dialogue tree JSON file under resources/dialogue/.",
    inputSchema: { path: z.string().describe("res:// path to a dialogue .json file") },
  },
  async ({ path }) => {
    try {
      return json(readJsonFile(path));
    } catch (e) {
      return fail(String(e));
    }
  }
);

server.registerTool(
  "write_dialogue",
  {
    title: "Write dialogue JSON",
    description:
      "Create or overwrite a dialogue tree JSON file under resources/dialogue/. Nodes use hierarchical IDs " +
      "(\"0\", \"0-0\", \"0-1\", \"0-1-0\", ...).",
    inputSchema: {
      path: z.string().describe("res:// path to a dialogue .json file"),
      data: z.record(z.string(), z.unknown()).describe("Dialogue JSON object"),
    },
  },
  async ({ path, data }) => {
    try {
      writeJsonFile(path, data);
      return json({ ok: true, path });
    } catch (e) {
      return fail(String(e));
    }
  }
);

// --- Start ------------------------------------------------------------------

buildIndex(); // so UID -> path resolution works for the first write
const transport = new StdioServerTransport();
await server.connect(transport);
console.error("crawler-content MCP server running on stdio");
