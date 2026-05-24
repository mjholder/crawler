import type { TresFile, TresValue } from "./types.js";

function escapeString(s: string): string {
  return s
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\n/g, "\\n")
    .replace(/\t/g, "\\t")
    .replace(/\r/g, "\\r");
}

function isSimple(v: TresValue): boolean {
  return (
    v.kind === "null" ||
    v.kind === "bool" ||
    v.kind === "int" ||
    v.kind === "float" ||
    v.kind === "string" ||
    v.kind === "stringname" ||
    v.kind === "extref" ||
    v.kind === "subref" ||
    v.kind === "call"
  );
}

export function writeValue(v: TresValue): string {
  switch (v.kind) {
    case "null":
      return "null";
    case "bool":
      return v.value ? "true" : "false";
    case "int":
      return String(v.value);
    case "float": {
      if (!isFinite(v.value)) return String(v.value);
      const s = String(v.value);
      return s.includes(".") || s.includes("e") ? s : s + ".0";
    }
    case "string":
      return `"${escapeString(v.value)}"`;
    case "stringname":
      return `&"${escapeString(v.value)}"`;
    case "extref":
      return `ExtResource("${v.id}")`;
    case "subref":
      return `SubResource("${v.id}")`;
    case "call": {
      const args = v.args.map(writeValue).join(", ");
      return `${v.name}(${args})`;
    }
    case "array": {
      if (v.items.length === 0) return "[]";
      if (v.items.every(isSimple)) {
        return `[${v.items.map(writeValue).join(", ")}]`;
      }
      // Complex items: one per line
      const items = v.items.map(writeValue).join(",\n");
      return `[${items}]`;
    }
    case "typedarray": {
      if (v.items.length === 0) return `Array[${v.typeHint}]([])`;
      if (v.items.every(isSimple)) {
        return `Array[${v.typeHint}]([${v.items.map(writeValue).join(", ")}])`;
      }
      const items = v.items.map(writeValue).join(",\n");
      return `Array[${v.typeHint}]([${items}])`;
    }
    case "dict": {
      if (v.entries.length === 0) return "{}";
      const entries = v.entries
        .map((e) => `${writeValue(e.key)}: ${writeValue(e.value)}`)
        .join(",\n");
      return `{\n${entries}\n}`;
    }
  }
}

type Attr = [string, string | number | undefined];

function sectionHeader(type: string, attrs: Attr[]): string {
  const parts: string[] = [type];
  for (const [key, val] of attrs) {
    if (val === undefined || val === null) continue;
    if (typeof val === "number") {
      parts.push(`${key}=${val}`);
    } else {
      parts.push(`${key}="${val}"`);
    }
  }
  return `[${parts.join(" ")}]`;
}

export function writeTres(file: TresFile): string {
  const lines: string[] = [];

  // Header
  lines.push(
    sectionHeader("gd_resource", [
      ["type", file.header.type],
      ["script_class", file.header.scriptClass],
      ["format", file.header.format ?? 3],
      ["uid", file.header.uid],
    ])
  );
  lines.push("");

  // Ext resources
  for (const ext of file.extResources) {
    const attrs: Attr[] = [["type", ext.type]];
    if (ext.uid) attrs.push(["uid", ext.uid]);
    if (ext.path) attrs.push(["path", ext.path]);
    attrs.push(["id", ext.id]);
    lines.push(sectionHeader("ext_resource", attrs));
  }
  if (file.extResources.length > 0) lines.push("");

  // Sub resources
  for (const sub of file.subResources) {
    lines.push(
      sectionHeader("sub_resource", [
        ["type", sub.type],
        ["id", sub.id],
      ])
    );
    for (const [key, val] of Object.entries(sub.props)) {
      lines.push(`${key} = ${writeValue(val)}`);
    }
    lines.push("");
  }

  // Resource section
  lines.push("[resource]");
  for (const [key, val] of Object.entries(file.resource)) {
    lines.push(`${key} = ${writeValue(val)}`);
  }
  lines.push("");

  return lines.join("\n");
}
