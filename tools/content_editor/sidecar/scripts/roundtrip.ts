/**
 * Round-trip test: parse every .tres in resources/, serialise, compare.
 *
 * Structural diffs (different values) are failures.
 * Whitespace-only diffs are allowed (Godot's parser is whitespace-insensitive).
 *
 * Usage:  npm run verify-tres --workspace=sidecar
 */
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { parseTres } from "../src/tres/parser.js";
import { writeTres } from "../src/tres/writer.js";

const PROJECT_ROOT = process.env.PROJECT_ROOT ?? join(import.meta.dirname, "../../../..");
const RESOURCES_DIR = join(PROJECT_ROOT, "resources");

function walk(dir: string, cb: (p: string) => void) {
  for (const entry of readdirSync(dir)) {
    const abs = join(dir, entry);
    if (statSync(abs).isDirectory()) walk(abs, cb);
    else if (entry.endsWith(".tres")) cb(abs);
  }
}

function normalise(s: string): string {
  // Collapse all runs of whitespace to single spaces and trim
  return s.replace(/\s+/g, " ").trim();
}

let passed = 0;
let failed = 0;

walk(RESOURCES_DIR, (absPath) => {
  const original = readFileSync(absPath, "utf8");
  let ast;
  try {
    ast = parseTres(original);
  } catch (e) {
    console.error(`PARSE ERROR  ${absPath}\n  ${e}`);
    failed++;
    return;
  }

  let serialised;
  try {
    serialised = writeTres(ast);
  } catch (e) {
    console.error(`WRITE ERROR  ${absPath}\n  ${e}`);
    failed++;
    return;
  }

  // Re-parse the serialised output to check structural equivalence
  let ast2;
  try {
    ast2 = parseTres(serialised);
  } catch (e) {
    console.error(`REPARSE ERROR  ${absPath}\n  ${e}`);
    failed++;
    return;
  }

  // Compare normalised JSON of both ASTs
  const j1 = normalise(JSON.stringify(ast));
  const j2 = normalise(JSON.stringify(ast2));
  if (j1 !== j2) {
    console.error(`DIFF  ${absPath}`);
    // Show first differing position
    let i = 0;
    while (i < j1.length && j1[i] === j2[i]) i++;
    console.error(`  at offset ${i}: ...${j1.slice(Math.max(0, i - 40), i + 80)}`);
    console.error(`               vs ...${j2.slice(Math.max(0, i - 40), i + 80)}`);
    failed++;
  } else {
    passed++;
  }
});

console.log(`\nRound-trip: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
