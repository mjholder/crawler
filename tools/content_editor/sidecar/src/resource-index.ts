/**
 * Cross-reference index: maps each UID (and res:// path) to the .tres files
 * that reference it.  Rebuilt on startup and updated via chokidar.
 */
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { PROJECT_ROOT } from "./config.js";
import chokidar from "chokidar";

const RESOURCES_DIR = join(PROJECT_ROOT, "resources");

// uid://... → set of res:// paths that contain that UID as an ExtResource
const refersTo = new Map<string, Set<string>>(); // uid → files that LINK TO it
// res:// path → uid for that file
const pathToUid = new Map<string, string>();
// uid → res:// path for that file
const uidToPath = new Map<string, string>();

// ---- Parsing helpers -------------------------------------------------------

const GD_RESOURCE_RE = /\[gd_resource[^\]]*uid="(uid:\/\/[^"]+)"/;
const EXT_RESOURCE_RE = /\[ext_resource[^\]]*uid="(uid:\/\/[^"]+)"/g;
const EXT_RESOURCE_PATH_RE = /\[ext_resource[^\]]*path="(res:\/\/[^"]+)"/g;

function indexFile(absPath: string): void {
  const resPath = "res://" + relative(PROJECT_ROOT, absPath).replace(/\\/g, "/");
  let content: string;
  try {
    content = readFileSync(absPath, "utf8");
  } catch {
    return;
  }

  // Own UID
  const own = content.match(GD_RESOURCE_RE);
  if (own) {
    pathToUid.set(resPath, own[1]);
    uidToPath.set(own[1], resPath);
  }

  // Referenced UIDs
  for (const m of content.matchAll(EXT_RESOURCE_RE)) {
    const uid = m[1];
    if (!refersTo.has(uid)) refersTo.set(uid, new Set());
    refersTo.get(uid)!.add(resPath);
  }
}

function removeFile(absPath: string): void {
  const resPath = "res://" + relative(PROJECT_ROOT, absPath).replace(/\\/g, "/");
  // Remove this file as a referrer
  for (const refs of refersTo.values()) {
    refs.delete(resPath);
  }
  const uid = pathToUid.get(resPath);
  if (uid) {
    pathToUid.delete(resPath);
    uidToPath.delete(uid);
  }
}

function walk(dir: string, cb: (absPath: string) => void): void {
  for (const entry of readdirSync(dir)) {
    const abs = join(dir, entry);
    const s = statSync(abs);
    if (s.isDirectory()) walk(abs, cb);
    else if (entry.endsWith(".tres")) cb(abs);
  }
}

// ---- Public API ------------------------------------------------------------

export interface IndexEntry {
  uid?: string;
  path: string;
  referenced_by: string[];
}

export function buildIndex(): void {
  refersTo.clear();
  pathToUid.clear();
  uidToPath.clear();

  walk(RESOURCES_DIR, indexFile);
  console.log(`Index built: ${pathToUid.size} resources, ${refersTo.size} unique UIDs referenced`);
}

export function getEntry(uidOrPath: string): IndexEntry | null {
  let uid: string | undefined;
  let resPath: string | undefined;

  if (uidOrPath.startsWith("uid://")) {
    uid = uidOrPath;
    resPath = uidToPath.get(uid);
  } else {
    resPath = uidOrPath;
    uid = pathToUid.get(resPath);
  }

  if (!resPath) return null;

  return {
    uid,
    path: resPath,
    referenced_by: Array.from(refersTo.get(uid ?? "") ?? []),
  };
}

/** Full index dump — UID → entry. */
export function fullIndex(): Record<string, IndexEntry> {
  const result: Record<string, IndexEntry> = {};
  for (const [uid, path] of uidToPath) {
    result[uid] = {
      uid,
      path,
      referenced_by: Array.from(refersTo.get(uid) ?? []),
    };
  }
  return result;
}

import type { GameSchema } from "./schema.js";

/** Compute the set of class names that are subclasses of (or equal to) the given class. */
function resolveSubclasses(scriptClass: string, schema: GameSchema): Set<string> {
  const result = new Set<string>();
  for (const [name, desc] of Object.entries(schema.classes)) {
    let current: string = desc.extends;
    if (name === scriptClass) { result.add(name); continue; }
    while (current) {
      if (current === scriptClass) { result.add(name); break; }
      current = schema.classes[current]?.extends ?? "";
    }
  }
  if (schema.classes[scriptClass]) result.add(scriptClass);
  return result;
}

/** List all .tres files of a given script_class, including all subclasses. */
export function listByClassWithSubclasses(scriptClass: string, schema: GameSchema): string[] {
  const classes = resolveSubclasses(scriptClass, schema);
  const all: string[] = [];
  for (const cls of classes) {
    all.push(...listByClass(cls));
  }
  // deduplicate (a file could match multiple patterns, though unlikely)
  return [...new Set(all)];
}

/** List all .tres files of a given script_class (by inspecting the file header). */
export function listByClass(scriptClass: string): string[] {
  const results: string[] = [];
  const pattern = `script_class="${scriptClass}"`;

  function search(dir: string): void {
    for (const entry of readdirSync(dir)) {
      const abs = join(dir, entry);
      const s = statSync(abs);
      if (s.isDirectory()) {
        search(abs);
      } else if (entry.endsWith(".tres")) {
        let content: string;
        try {
          content = readFileSync(abs, "utf8").slice(0, 300); // only need the header line
        } catch {
          continue;
        }
        if (content.includes(pattern)) {
          results.push("res://" + relative(PROJECT_ROOT, abs).replace(/\\/g, "/"));
        }
      }
    }
  }

  search(RESOURCES_DIR);
  return results;
}

export function watchIndex(): void {
  const watcher = chokidar.watch(RESOURCES_DIR, {
    ignored: /(^|[/\\])\../,
    persistent: false,
    ignoreInitial: true,
  });

  watcher.on("add", (p) => indexFile(p));
  watcher.on("change", (p) => { removeFile(p); indexFile(p); });
  watcher.on("unlink", (p) => removeFile(p));
}
