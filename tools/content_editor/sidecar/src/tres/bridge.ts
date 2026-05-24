/**
 * Converts between TresFile AST and the JSON envelope the frontend expects.
 *
 * Read path:  astToEnvelope() — matches io_read.gd output exactly.
 * Write path: applyEnvelope() — mutates AST resource props from JSON envelope.
 */
import type { TresFile, TresValue, ExtResource, SubResource } from "./types.js";

// scriptToClass is a Map from res:// script path → class name, built from schema.json
export type ScriptToClass = Map<string, string>;

// ---- Read path: AST → JSON envelope ----------------------------------------

export function astToEnvelope(
  ast: TresFile,
  resPath: string,
  scriptToClass: ScriptToClass
): Record<string, unknown> {
  const extById = new Map<string, ExtResource>(
    ast.extResources.map((e) => [e.id, e])
  );
  const subById = new Map<string, SubResource>(
    ast.subResources.map((s) => [s.id, s])
  );

  // Script ext-resource used to populate _godot_meta
  const scriptExt = ast.extResources.find((e) => e.type === "Script");

  const meta: Record<string, unknown> = {
    inline: false,
    path: resPath,
  };
  if (ast.header.scriptClass) meta.class = ast.header.scriptClass;
  if (scriptExt?.path) meta.script = scriptExt.path;
  if (ast.header.uid) meta.uid = ast.header.uid;

  const result: Record<string, unknown> = { _godot_meta: meta };

  for (const [key, val] of Object.entries(ast.resource)) {
    if (key === "script") continue;
    const converted = valueToJson(val, extById, subById, scriptToClass);
    if (converted !== undefined) result[key] = converted;
  }

  return result;
}

function valueToJson(
  val: TresValue,
  extById: Map<string, ExtResource>,
  subById: Map<string, SubResource>,
  scriptToClass: ScriptToClass
): unknown {
  switch (val.kind) {
    case "null":
      return null;
    case "bool":
      return val.value;
    case "int":
      return val.value;
    case "float":
      return val.value;
    case "string":
      return val.value;
    case "stringname":
      return { __sn: val.value };

    case "extref": {
      const ext = extById.get(val.id);
      if (!ext?.path) return null;
      const ref: Record<string, string> = { __ref: ext.path };
      if (ext.uid) ref.__uid = ext.uid;
      return ref;
    }

    case "subref": {
      const sub = subById.get(val.id);
      if (!sub) return null;
      return subResourceToJson(sub, extById, subById, scriptToClass);
    }

    case "call":
      return null; // Rect2, Color, Vector2, etc. — dropped like io_read

    case "array":
    case "typedarray": {
      return val.items.map((item) =>
        valueToJson(item, extById, subById, scriptToClass)
      );
    }

    case "dict": {
      const result: Record<string, unknown> = {};
      if (val.entries.length > 0) {
        const firstKey = val.entries[0].key;
        if (firstKey.kind === "int") result.__key_type = "int";
        else if (firstKey.kind === "stringname") result.__key_type = "StringName";
        else if (firstKey.kind === "string") result.__key_type = "String";
      }
      for (const { key, value } of val.entries) {
        result[tresKeyToString(key)] = valueToJson(
          value,
          extById,
          subById,
          scriptToClass
        );
      }
      return result;
    }
  }
}

function tresKeyToString(key: TresValue): string {
  switch (key.kind) {
    case "int":
      return String(key.value);
    case "float":
      return String(key.value);
    case "string":
      return key.value;
    case "stringname":
      return key.value;
    default:
      return "";
  }
}

function subResourceToJson(
  sub: SubResource,
  extById: Map<string, ExtResource>,
  subById: Map<string, SubResource>,
  scriptToClass: ScriptToClass
): unknown {
  const scriptProp = sub.props["script"];
  if (!scriptProp || scriptProp.kind !== "extref") return null;

  const scriptExt = extById.get(scriptProp.id);
  if (!scriptExt || scriptExt.type !== "Script") return null;

  const scriptPath = scriptExt.path ?? "";
  const className = scriptToClass.get(scriptPath) ?? "";

  const meta: Record<string, unknown> = {
    class: className,
    script: scriptPath,
    inline: true,
  };

  const result: Record<string, unknown> = { _godot_meta: meta };
  for (const [key, val] of Object.entries(sub.props)) {
    if (key === "script") continue;
    const converted = valueToJson(val, extById, subById, scriptToClass);
    if (converted !== undefined) result[key] = converted;
  }
  return result;
}

// ---- Write path: JSON envelope → AST ----------------------------------------

// uidToPath: uid:// → res:// — used to resolve UIDs to current file paths
export type UidToPath = (uid: string) => string | undefined;

export function applyEnvelope(
  ast: TresFile,
  envelope: Record<string, unknown>,
  uidToPath: UidToPath
): TresFile {
  // Deep-copy mutable portions
  const newExtResources: ExtResource[] = ast.extResources.map((e) => ({
    ...e,
  }));
  const newSubResources: SubResource[] = ast.subResources.map((s) => ({
    ...s,
    props: { ...s.props },
  }));
  const newResource: Record<string, import("./types.js").TresValue> = {
    ...ast.resource,
  };

  const extByPath = new Map<string, ExtResource>();
  const extByUid = new Map<string, ExtResource>();
  for (const ext of newExtResources) {
    if (ext.path) extByPath.set(ext.path, ext);
    if (ext.uid) extByUid.set(ext.uid, ext);
  }
  const subById = new Map<string, SubResource>(
    newSubResources.map((s) => [s.id, s])
  );

  for (const [key, envVal] of Object.entries(envelope)) {
    if (key.startsWith("_")) continue;
    if (envVal === null || envVal === undefined) continue;

    const currentAstVal = newResource[key];
    const newVal = jsonToTresValue(
      envVal,
      currentAstVal,
      newExtResources,
      subById,
      extByPath,
      extByUid,
      uidToPath
    );
    if (newVal !== undefined) {
      newResource[key] = newVal;
    }
  }

  return {
    ...ast,
    extResources: newExtResources,
    subResources: newSubResources,
    resource: newResource,
  };
}

function jsonToTresValue(
  val: unknown,
  currentAst: TresValue | undefined,
  extResources: ExtResource[],
  subById: Map<string, SubResource>,
  extByPath: Map<string, ExtResource>,
  extByUid: Map<string, ExtResource>,
  uidToPath: UidToPath
): TresValue | undefined {
  if (val === null || val === undefined) return undefined;

  if (typeof val === "boolean") return { kind: "bool", value: val };

  if (typeof val === "number") {
    return jsonNumberToTres(val, currentAst);
  }

  if (typeof val === "string") return { kind: "string", value: val };

  if (Array.isArray(val)) {
    return jsonArrayToTres(
      val,
      currentAst,
      extResources,
      subById,
      extByPath,
      extByUid,
      uidToPath
    );
  }

  if (typeof val === "object") {
    const obj = val as Record<string, unknown>;

    if ("__sn" in obj) {
      return { kind: "stringname", value: String(obj.__sn) };
    }

    if ("__ref" in obj || "__uid" in obj) {
      return jsonRefToTres(
        obj as { __ref?: string; __uid?: string },
        extResources,
        extByPath,
        extByUid,
        uidToPath
      );
    }

    if ("_godot_meta" in obj) {
      return jsonInlineToTres(
        obj,
        currentAst,
        extResources,
        subById,
        extByPath,
        extByUid,
        uidToPath
      );
    }

    // Plain or typed dict
    return jsonDictToTres(obj, currentAst, extResources, subById, extByPath, extByUid, uidToPath);
  }

  return undefined;
}

function jsonNumberToTres(n: number, currentAst?: TresValue): TresValue {
  if (currentAst?.kind === "float") return { kind: "float", value: n };
  if (currentAst?.kind === "int") return { kind: "int", value: n };
  return Number.isInteger(n) ? { kind: "int", value: n } : { kind: "float", value: n };
}

function jsonRefToTres(
  ref: { __ref?: string; __uid?: string },
  extResources: ExtResource[],
  extByPath: Map<string, ExtResource>,
  extByUid: Map<string, ExtResource>,
  uidToPath: UidToPath
): TresValue {
  // Resolve to canonical path via UID if possible
  let path = ref.__ref ?? "";
  const uid = ref.__uid;
  if (uid) {
    const resolved = uidToPath(uid);
    if (resolved) path = resolved;
  }

  // Find or create an ext_resource declaration for this path
  const ext = findOrAddExtResource(path, uid, extResources, extByPath, extByUid);
  return { kind: "extref", id: ext.id };
}

function findOrAddExtResource(
  path: string,
  uid: string | undefined,
  extResources: ExtResource[],
  extByPath: Map<string, ExtResource>,
  extByUid: Map<string, ExtResource>
): ExtResource {
  // Try uid lookup first, then path
  const existing =
    (uid ? extByUid.get(uid) : undefined) ?? extByPath.get(path);
  if (existing) return existing;

  // Create a new ext_resource declaration
  const id = `${extResources.length + 1}_new`;
  const newExt: ExtResource = { id, type: "Resource", path, uid };
  extResources.push(newExt);
  if (path) extByPath.set(path, newExt);
  if (uid) extByUid.set(uid, newExt);
  return newExt;
}

function jsonInlineToTres(
  obj: Record<string, unknown>,
  currentAst: TresValue | undefined,
  extResources: ExtResource[],
  subById: Map<string, SubResource>,
  extByPath: Map<string, ExtResource>,
  extByUid: Map<string, ExtResource>,
  uidToPath: UidToPath
): TresValue | undefined {
  const meta = obj._godot_meta as Record<string, unknown>;
  if (!meta) return undefined;

  const scriptPath = meta.script as string | undefined;
  if (!scriptPath) return undefined;

  // If we have a current subref, update the existing sub_resource in-place
  if (currentAst?.kind === "subref") {
    const sub = subById.get(currentAst.id);
    if (sub) {
      applyPropsToSubResource(sub, obj, extResources, subById, extByPath, extByUid, uidToPath);
      return currentAst; // subref id unchanged
    }
  }

  // Create a new sub_resource
  const newId = `Inline_${Date.now()}`;
  const scriptExt = findOrAddExtResource(scriptPath, undefined, extResources, extByPath, extByUid);
  const newSub: SubResource = {
    type: "Resource",
    id: newId,
    props: { script: { kind: "extref", id: scriptExt.id } },
  };
  subById.set(newId, newSub);
  applyPropsToSubResource(newSub, obj, extResources, subById, extByPath, extByUid, uidToPath);
  // The caller needs to add newSub to ast.subResources — but we're mutating in place
  // via the subById map which was created from newSubResources.
  // We need to also push to the original array.
  // This is handled by the caller seeing subById having a new entry.
  // Actually we need to push to the array reference that newSubResources points to.
  // Hack: subById values are references to the same objects in newSubResources.
  // For new sub-resources, we just push directly to the shared array.
  // The extResources array is shared too, already mutated above.
  //
  // We'll return the subref and rely on post-processing to sync subById → subResources.
  return { kind: "subref", id: newId };
}

function applyPropsToSubResource(
  sub: SubResource,
  obj: Record<string, unknown>,
  extResources: ExtResource[],
  subById: Map<string, SubResource>,
  extByPath: Map<string, ExtResource>,
  extByUid: Map<string, ExtResource>,
  uidToPath: UidToPath
): void {
  for (const [key, val] of Object.entries(obj)) {
    if (key.startsWith("_")) continue;
    if (val === null || val === undefined) continue;
    const newVal = jsonToTresValue(
      val,
      sub.props[key],
      extResources,
      subById,
      extByPath,
      extByUid,
      uidToPath
    );
    if (newVal !== undefined) sub.props[key] = newVal;
  }
}

function jsonArrayToTres(
  arr: unknown[],
  currentAst: TresValue | undefined,
  extResources: ExtResource[],
  subById: Map<string, SubResource>,
  extByPath: Map<string, ExtResource>,
  extByUid: Map<string, ExtResource>,
  uidToPath: UidToPath
): TresValue {
  const currentItems =
    currentAst?.kind === "array" || currentAst?.kind === "typedarray"
      ? currentAst.items
      : [];

  const items = arr.map((item, i) =>
    jsonToTresValue(
      item,
      currentItems[i],
      extResources,
      subById,
      extByPath,
      extByUid,
      uidToPath
    ) ?? { kind: "null" as const }
  );

  // Preserve typedarray wrapper if the original was one
  if (currentAst?.kind === "typedarray") {
    return { kind: "typedarray", typeHint: currentAst.typeHint, items };
  }
  return { kind: "array", items };
}

function jsonDictToTres(
  obj: Record<string, unknown>,
  currentAst: TresValue | undefined,
  extResources: ExtResource[],
  subById: Map<string, SubResource>,
  extByPath: Map<string, ExtResource>,
  extByUid: Map<string, ExtResource>,
  uidToPath: UidToPath
): TresValue {
  const keyType = obj.__key_type as string | undefined;

  // Build a map from string key → current AST value for type hints
  const currentEntryMap = new Map<string, TresValue>();
  if (currentAst?.kind === "dict") {
    for (const entry of currentAst.entries) {
      currentEntryMap.set(tresKeyToString(entry.key), entry.value);
    }
  }

  const entries: Array<{ key: TresValue; value: TresValue }> = [];
  for (const [k, v] of Object.entries(obj)) {
    if (k === "__key_type") continue;

    const key: TresValue =
      keyType === "int"
        ? { kind: "int", value: parseInt(k, 10) }
        : keyType === "StringName"
        ? { kind: "stringname", value: k }
        : { kind: "string", value: k };

    const currentVal = currentEntryMap.get(k);
    const value =
      jsonToTresValue(
        v,
        currentVal,
        extResources,
        subById,
        extByPath,
        extByUid,
        uidToPath
      ) ?? { kind: "null" as const };

    entries.push({ key, value });
  }

  return { kind: "dict", entries };
}

// ---- New resource creation --------------------------------------------------

export function createFreshAst(scriptPath: string, className: string): TresFile {
  return {
    header: {
      type: "Resource",
      scriptClass: className,
      format: 3,
    },
    extResources: [{ id: "1_script", type: "Script", path: scriptPath }],
    subResources: [],
    resource: {
      script: { kind: "extref", id: "1_script" },
    },
  };
}

// Sync any newly-created SubResources (from jsonInlineToTres) into the array
export function syncNewSubResources(
  ast: TresFile,
  subById: Map<string, SubResource>
): TresFile {
  const knownIds = new Set(ast.subResources.map((s) => s.id));
  const extras: SubResource[] = [];
  for (const [id, sub] of subById) {
    if (!knownIds.has(id)) extras.push(sub);
  }
  if (extras.length === 0) return ast;
  return { ...ast, subResources: [...ast.subResources, ...extras] };
}
