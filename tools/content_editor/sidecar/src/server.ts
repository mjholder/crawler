import Fastify from "fastify";
import cors from "@fastify/cors";
import { readResource, writeResource } from "./godot.js";
import { getSchema, refreshSchema } from "./schema.js";
import {
  buildIndex,
  watchIndex,
  listByClass,
  listByClassWithSubclasses,
  getEntry,
  fullIndex,
} from "./resource-index.js";
import { listAssets } from "./asset-index.js";
import { lintResource } from "./linter.js";

// --- Startup ----------------------------------------------------------------

buildIndex();
watchIndex();

const app = Fastify({ logger: true });
await app.register(cors, { origin: "http://localhost:5173" });

// --- Schema -----------------------------------------------------------------

app.get("/schema", async () => {
  return getSchema();
});

app.post("/schema/refresh", async () => {
  return refreshSchema();
});

// --- Resource listing -------------------------------------------------------

// GET /types/:class → list of res:// paths for that script_class (includes subclasses)
app.get<{ Params: { cls: string } }>(
  "/types/:cls",
  async (req) => {
    return listByClassWithSubclasses(req.params.cls, getSchema());
  }
);

// GET /assets?type=Texture2D|AudioStream|PackedScene|SpriteFrames
app.get<{ Querystring: { type: string } }>(
  "/assets",
  async (req, reply) => {
    const { type } = req.query;
    if (!type) return reply.code(400).send({ error: "type required" });
    return listAssets(type);
  }
);

// --- Resource creation ------------------------------------------------------

// POST /resource/new?path=res://...&class=WeaponData
// Creates a blank resource at the given path from the class's script.
// Errors if the file already exists.
app.post<{ Querystring: { path: string; class: string } }>(
  "/resource/new",
  async (req, reply) => {
    const { path, class: cls } = req.query;
    if (!path || !cls) return reply.code(400).send({ error: "path and class required" });

    const schema = getSchema();
    const classDesc = schema.classes[cls];
    if (!classDesc) return reply.code(400).send({ error: `Unknown class: ${cls}` });

    // Check the file doesn't already exist
    const { existsSync } = await import("node:fs");
    const { join } = await import("node:path");
    const { PROJECT_ROOT } = await import("./godot.js");
    const absPath = join(PROJECT_ROOT, path.replace("res://", ""));
    if (existsSync(absPath)) {
      return reply.code(409).send({ error: "File already exists" });
    }

    // Minimal JSON — io_write.gd will create from _godot_meta.script
    const minimal = {
      _godot_meta: { class: cls, script: classDesc.script, inline: false, path },
    };

    try {
      await writeResource(path, minimal);
      buildIndex(); // pick up the new file
      const data = await readResource(path);
      return data;
    } catch (e) {
      return reply.code(500).send({ error: String(e) });
    }
  }
);

// --- Resource CRUD ----------------------------------------------------------

// GET /resource?path=res://...
app.get<{ Querystring: { path: string } }>(
  "/resource",
  async (req, reply) => {
    const { path } = req.query;
    if (!path) return reply.code(400).send({ error: "path required" });
    try {
      const data = await readResource(path);
      return data;
    } catch (e) {
      return reply.code(500).send({ error: String(e) });
    }
  }
);

// POST /resource?path=res://...  body: the JSON object from io_read
app.post<{ Querystring: { path: string }; Body: unknown }>(
  "/resource",
  { schema: { body: {} } }, // allow any body shape
  async (req, reply) => {
    const { path } = req.query;
    if (!path) return reply.code(400).send({ error: "path required" });
    try {
      await writeResource(path, req.body);
      // Rebuild index entry for this file
      buildIndex();
      return { ok: true };
    } catch (e) {
      return reply.code(500).send({ error: String(e) });
    }
  }
);

// --- Cross-reference index --------------------------------------------------

app.get("/index", async () => fullIndex());

app.get<{ Querystring: { uid?: string; path?: string } }>(
  "/index/entry",
  async (req, reply) => {
    const key = req.query.uid ?? req.query.path;
    if (!key) return reply.code(400).send({ error: "uid or path required" });
    const entry = getEntry(key);
    if (!entry) return reply.code(404).send({ error: "not found" });
    return entry;
  }
);

// --- Linter -----------------------------------------------------------------

// GET /lint?path=res://...  — lint one resource (reads it first)
app.get<{ Querystring: { path: string } }>(
  "/lint",
  async (req, reply) => {
    const { path } = req.query;
    if (!path) return reply.code(400).send({ error: "path required" });
    try {
      const data = await readResource(path);
      return lintResource(data);
    } catch (e) {
      return reply.code(500).send({ error: String(e) });
    }
  }
);

// POST /lint  body: resource JSON — lint without hitting disk
app.post<{ Body: unknown }>(
  "/lint",
  { schema: { body: {} } },
  async (req) => {
    return lintResource(req.body);
  }
);

// --- Start ------------------------------------------------------------------

await app.listen({ port: 5174, host: "127.0.0.1" });
console.log("Content editor sidecar running on http://localhost:5174");
