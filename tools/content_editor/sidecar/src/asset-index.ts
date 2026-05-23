/**
 * Asset file listing for built-in Godot resource types (Texture2D, AudioStream, PackedScene, SpriteFrames).
 * These live under assets/ and scenes/ rather than resources/, so they can't be found by script_class scan.
 */
import { readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { PROJECT_ROOT } from "./godot.js";

const ASSET_EXTS: Record<string, string[]> = {
  Texture2D:    [".png", ".jpg", ".jpeg", ".svg", ".webp"],
  AudioStream:  [".ogg", ".wav", ".mp3"],
  PackedScene:  [".tscn"],
  SpriteFrames: [".tres"],
};

/** Walk a directory and collect files whose extension is in the allowed set. */
function walk(dir: string, exts: Set<string>, results: string[]): void {
  let entries: string[];
  try {
    entries = readdirSync(dir);
  } catch {
    return;
  }
  for (const entry of entries) {
    const abs = join(dir, entry);
    let s;
    try { s = statSync(abs); } catch { continue; }
    if (s.isDirectory()) {
      walk(abs, exts, results);
    } else {
      const dot = entry.lastIndexOf(".");
      if (dot !== -1 && exts.has(entry.slice(dot))) {
        results.push("res://" + relative(PROJECT_ROOT, abs).replace(/\\/g, "/"));
      }
    }
  }
}

export function listAssets(resourceType: string): string[] {
  const exts = ASSET_EXTS[resourceType];
  if (!exts) return [];

  const extSet = new Set(exts);
  const results: string[] = [];

  walk(join(PROJECT_ROOT, "assets"), extSet, results);

  // PackedScene: also scan scenes/
  if (resourceType === "PackedScene") {
    walk(join(PROJECT_ROOT, "scenes"), extSet, results);
  }

  return results.sort();
}
