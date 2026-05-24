/**
 * Resource I/O for .tres files using a native TypeScript parser.
 *
 * readResource / writeResource no longer spawn Godot — they parse and serialise
 * .tres directly.  exportSchema still calls Godot (rare, manual operation).
 */
import { spawn } from "node:child_process";
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { parseTres } from "./tres/parser.js";
import { writeTres } from "./tres/writer.js";
import {
  astToEnvelope,
  applyEnvelope,
  createFreshAst,
  syncNewSubResources,
} from "./tres/bridge.js";
import { getEntry } from "./resource-index.js";
import { PROJECT_ROOT } from "./config.js";
export { PROJECT_ROOT } from "./config.js";

export const GODOT_BIN = process.env.GODOT_EXECUTABLE ?? "godot";

function runGodot(scriptResPath: string, userArgs: string[]): Promise<string> {
  return new Promise((resolve, reject) => {
    const args = [
      "--headless",
      "--path",
      PROJECT_ROOT,
      "--script",
      scriptResPath,
      "--",
      ...userArgs,
    ];

    const child = spawn(GODOT_BIN, args, { stdio: ["pipe", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk: Buffer) => (stdout += chunk.toString()));
    child.stderr.on("data", (chunk: Buffer) => (stderr += chunk.toString()));

    child.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(`Godot exited ${code}: ${stderr.trim()}`));
      } else {
        const jsonStart = stdout.search(/[{[]/);
        const clean = jsonStart >= 0 ? stdout.slice(jsonStart) : stdout;
        resolve(clean.trim());
      }
    });

    child.on("error", (err) => reject(err));
    child.stdin.end();
  });
}

function buildScriptToClass(): Map<string, string> {
  try {
    // Import lazily to avoid circular deps — schema imports godot.ts for exportSchema
    // but we only need the JSON file here.
    const schemaPath = join(PROJECT_ROOT, "tools/content_editor/schema.json");
    if (!existsSync(schemaPath)) return new Map();
    const schema = JSON.parse(readFileSync(schemaPath, "utf8")) as {
      classes: Record<string, { script: string }>;
    };
    const map = new Map<string, string>();
    for (const [cls, desc] of Object.entries(schema.classes)) {
      map.set(desc.script, cls);
    }
    return map;
  } catch {
    return new Map();
  }
}

function uidToPathFn(uid: string): string | undefined {
  return getEntry(uid)?.path;
}

/** Read a .tres and return its JSON envelope representation. */
export async function readResource(resPath: string): Promise<unknown> {
  const absPath = join(PROJECT_ROOT, resPath.replace("res://", ""));
  const text = readFileSync(absPath, "utf8");
  const ast = parseTres(text);
  const scriptToClass = buildScriptToClass();
  return astToEnvelope(ast, resPath, scriptToClass);
}

/** Write a JSON envelope back to its .tres file. */
export async function writeResource(
  resPath: string,
  data: unknown
): Promise<void> {
  const absPath = join(PROJECT_ROOT, resPath.replace("res://", ""));
  const envelope = data as Record<string, unknown>;

  let ast = existsSync(absPath)
    ? parseTres(readFileSync(absPath, "utf8"))
    : (() => {
        const meta = envelope._godot_meta as Record<string, unknown>;
        return createFreshAst(
          String(meta?.script ?? ""),
          String(meta?.class ?? "")
        );
      })();

  const subById = new Map(ast.subResources.map((s) => [s.id, s]));
  ast = applyEnvelope(ast, envelope, uidToPathFn);
  ast = syncNewSubResources(ast, subById);

  writeFileSync(absPath, writeTres(ast), "utf8");
}

/** Run the schema export script and return the raw JSON string. */
export async function exportSchema(): Promise<string> {
  return runGodot("res://tools/content_editor/godot/export_schema.gd", []);
}
