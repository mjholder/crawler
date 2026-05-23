/**
 * Wrapper around Godot headless subprocess invocations.
 *
 * All I/O with .tres files flows through here so the rest of the sidecar
 * never needs to know the subprocess details.
 */
import { spawn } from "node:child_process";
import { writeFileSync, unlinkSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { randomBytes } from "node:crypto";

// Project root is three levels up from sidecar/src/
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
export const PROJECT_ROOT = resolve(__dirname, "../../../..");

export const GODOT_BIN = process.env.GODOT_EXECUTABLE ?? "godot";

function runGodot(
  scriptResPath: string,
  userArgs: string[]
): Promise<string> {
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
        // Strip the Godot engine banner ("Godot Engine vX.Y..." on stdout)
        // by finding the first { or [ that starts the JSON payload.
        const jsonStart = stdout.search(/[{[]/);
        const clean = jsonStart >= 0 ? stdout.slice(jsonStart) : stdout;
        resolve(clean.trim());
      }
    });

    child.on("error", (err) => reject(err));

    child.stdin.end();
  });
}

/** Read a .tres and return its JSON representation. */
export async function readResource(resPath: string): Promise<unknown> {
  const raw = await runGodot(
    "res://tools/content_editor/godot/io_read.gd",
    [resPath]
  );
  return JSON.parse(raw);
}

/** Write a JSON representation back to its .tres file. */
export async function writeResource(
  resPath: string,
  data: unknown
): Promise<void> {
  // Write to a temp file so we avoid stdin buffer-size limits in Godot.
  const tmpPath = join(tmpdir(), `ce_write_${randomBytes(6).toString("hex")}.json`);
  writeFileSync(tmpPath, JSON.stringify(data));
  try {
    await runGodot("res://tools/content_editor/godot/io_write.gd", [resPath, tmpPath]);
  } finally {
    // Clean up if Godot didn't already delete it
    if (existsSync(tmpPath)) unlinkSync(tmpPath);
  }
}

/** Run the schema export script and return the raw JSON string. */
export async function exportSchema(): Promise<string> {
  return runGodot("res://tools/content_editor/godot/export_schema.gd", []);
}
