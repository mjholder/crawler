/**
 * Loads and caches the game schema (exported from Godot resource classes).
 * Merges annotations.json to fill in untyped Array[Resource] field semantics.
 */
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { PROJECT_ROOT } from "./config.js";
import { exportSchema } from "./godot.js";

export interface PropDescriptor {
  name: string;
  type: string;
  // For enum fields
  enum_ref?: string;
  enum_values?: Record<string, number>;
  // For Array fields
  element_type?: string;
  // For Dictionary fields
  key_type?: string;
  value_type?: string;
  // For Resource/Object fields
  resource_type?: string;
}

export interface ClassDescriptor {
  script: string;
  extends: string;
  properties: PropDescriptor[];
}

export interface GameSchema {
  classes: Record<string, ClassDescriptor>;
  enums: Record<string, Record<string, number>>;
}

const SCHEMA_PATH = join(PROJECT_ROOT, "tools/content_editor/schema.json");

let _cached: GameSchema | null = null;

export function getSchema(): GameSchema {
  if (_cached) return _cached;

  if (existsSync(SCHEMA_PATH)) {
    _cached = JSON.parse(readFileSync(SCHEMA_PATH, "utf8")) as GameSchema;
    return _cached;
  }

  throw new Error(
    "schema.json not found. Run `npm run schema` from tools/content_editor/ to generate it."
  );
}

export async function refreshSchema(): Promise<GameSchema> {
  console.log("Exporting schema from Godot...");
  const raw = await exportSchema();
  writeFileSync(SCHEMA_PATH, raw, "utf8");
  _cached = JSON.parse(raw) as GameSchema;
  console.log(
    `Schema refreshed: ${Object.keys(_cached.classes).length} classes, ${Object.keys(_cached.enums).length} enums`
  );
  return _cached;
}

export function invalidateSchema(): void {
  _cached = null;
}

/**
 * Returns the flat ordered property list for a class, following inheritance.
 * Parent properties come first (matches Godot's get_property_list order).
 */
export function getAllProperties(
  className: string,
  schema: GameSchema
): PropDescriptor[] {
  const cls = schema.classes[className];
  if (!cls) return [];

  const parentProps = cls.extends
    ? getAllProperties(cls.extends, schema)
    : [];

  // Deduplicate: own props override parent props of the same name
  const ownNames = new Set(cls.properties.map((p) => p.name));
  return [
    ...parentProps.filter((p) => !ownNames.has(p.name)),
    ...cls.properties,
  ];
}
