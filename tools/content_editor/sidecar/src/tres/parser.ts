import type {
  TresFile,
  TresHeader,
  ExtResource,
  SubResource,
  TresValue,
} from "./types.js";

// ---- Value parser -----------------------------------------------------------

class ValueParser {
  src: string;
  pos: number;

  constructor(src: string, startPos = 0) {
    this.src = src;
    this.pos = startPos;
  }

  private skipWs(): void {
    while (
      this.pos < this.src.length &&
      (this.src[this.pos] === " " || this.src[this.pos] === "\t")
    ) {
      this.pos++;
    }
  }

  private skipWsNl(): void {
    while (
      this.pos < this.src.length &&
      /[ \t\r\n]/.test(this.src[this.pos])
    ) {
      this.pos++;
    }
  }

  private peek(): string {
    return this.src[this.pos] ?? "";
  }

  private at(offset: number): string {
    return this.src[this.pos + offset] ?? "";
  }

  private consume(): string {
    return this.src[this.pos++] ?? "";
  }

  private startsWith(s: string): boolean {
    return this.src.startsWith(s, this.pos);
  }

  parseString(): string {
    this.pos++; // consume opening "
    let result = "";
    while (this.pos < this.src.length) {
      const c = this.src[this.pos++];
      if (c === '"') break;
      if (c === "\\") {
        const esc = this.src[this.pos++] ?? "";
        switch (esc) {
          case "n":
            result += "\n";
            break;
          case "t":
            result += "\t";
            break;
          case "r":
            result += "\r";
            break;
          case '"':
            result += '"';
            break;
          case "\\":
            result += "\\";
            break;
          default:
            result += "\\" + esc;
        }
      } else {
        result += c;
      }
    }
    return result;
  }

  private parseNumber(): TresValue {
    let s = "";
    if (this.peek() === "-") s += this.consume();
    while (
      this.pos < this.src.length &&
      this.src[this.pos] >= "0" &&
      this.src[this.pos] <= "9"
    ) {
      s += this.consume();
    }
    if (this.peek() === ".") {
      s += this.consume();
      while (
        this.pos < this.src.length &&
        this.src[this.pos] >= "0" &&
        this.src[this.pos] <= "9"
      ) {
        s += this.consume();
      }
      if (this.peek() === "e" || this.peek() === "E") {
        s += this.consume();
        if (this.peek() === "+" || this.peek() === "-") s += this.consume();
        while (
          this.pos < this.src.length &&
          this.src[this.pos] >= "0" &&
          this.src[this.pos] <= "9"
        ) {
          s += this.consume();
        }
      }
      return { kind: "float", value: parseFloat(s) };
    }
    return { kind: "int", value: parseInt(s, 10) };
  }

  private parseIdent(): string {
    let s = "";
    while (
      this.pos < this.src.length &&
      /[a-zA-Z0-9_]/.test(this.src[this.pos])
    ) {
      s += this.consume();
    }
    return s;
  }

  private parseArray(): TresValue {
    this.pos++; // consume [
    const items: TresValue[] = [];
    while (true) {
      this.skipWsNl();
      if (this.peek() === "]") {
        this.pos++;
        break;
      }
      if (this.peek() === "") break;
      items.push(this.parseValue());
      this.skipWsNl();
      if (this.peek() === ",") this.pos++;
    }
    return { kind: "array", items };
  }

  private parseDict(): TresValue {
    this.pos++; // consume {
    const entries: Array<{ key: TresValue; value: TresValue }> = [];
    while (true) {
      this.skipWsNl();
      if (this.peek() === "}") {
        this.pos++;
        break;
      }
      if (this.peek() === "") break;
      const key = this.parseValue();
      this.skipWsNl();
      if (this.peek() === ":") this.pos++;
      this.skipWsNl();
      const value = this.parseValue();
      entries.push({ key, value });
      this.skipWsNl();
      if (this.peek() === ",") this.pos++;
    }
    return { kind: "dict", entries };
  }

  // Collect the raw type-hint string inside Array[...] preserving nested brackets/strings
  private parseTypeHint(): string {
    this.pos++; // consume [
    let hint = "";
    let depth = 1;
    while (this.pos < this.src.length) {
      const c = this.src[this.pos];
      if (c === "[") {
        depth++;
        hint += c;
        this.pos++;
      } else if (c === "]") {
        depth--;
        if (depth === 0) {
          this.pos++;
          break;
        }
        hint += c;
        this.pos++;
      } else if (c === '"') {
        // Quoted string inside type hint (e.g. ExtResource("id"))
        hint += c;
        this.pos++;
        while (this.pos < this.src.length) {
          const sc = this.src[this.pos];
          if (sc === '"') {
            hint += sc;
            this.pos++;
            break;
          }
          if (sc === "\\") {
            hint += sc;
            this.pos++;
            hint += this.src[this.pos++] ?? "";
          } else {
            hint += sc;
            this.pos++;
          }
        }
      } else {
        hint += c;
        this.pos++;
      }
    }
    return hint;
  }

  parseValue(): TresValue {
    this.skipWs();
    const c = this.peek();

    if (c === "") return { kind: "null" };

    if (this.startsWith("null")) {
      this.pos += 4;
      return { kind: "null" };
    }

    if (this.startsWith("true")) {
      this.pos += 4;
      return { kind: "bool", value: true };
    }

    if (this.startsWith("false")) {
      this.pos += 5;
      return { kind: "bool", value: false };
    }

    if (c === '"') {
      return { kind: "string", value: this.parseString() };
    }

    if (c === "&") {
      this.pos++;
      if (this.peek() === '"') {
        return { kind: "stringname", value: this.parseString() };
      }
      return { kind: "null" };
    }

    if (c === "-" && /[0-9]/.test(this.at(1))) {
      return this.parseNumber();
    }

    if (c >= "0" && c <= "9") {
      return this.parseNumber();
    }

    if (c === "[") {
      return this.parseArray();
    }

    if (c === "{") {
      return this.parseDict();
    }

    if (/[a-zA-Z_]/.test(c)) {
      const ident = this.parseIdent();

      if (ident === "ExtResource") {
        this.skipWs();
        if (this.peek() === "(") {
          this.pos++;
          this.skipWsNl();
          if (this.peek() === '"') {
            const id = this.parseString();
            this.skipWsNl();
            if (this.peek() === ")") this.pos++;
            return { kind: "extref", id };
          }
        }
        return { kind: "null" };
      }

      if (ident === "SubResource") {
        this.skipWs();
        if (this.peek() === "(") {
          this.pos++;
          this.skipWsNl();
          if (this.peek() === '"') {
            const id = this.parseString();
            this.skipWsNl();
            if (this.peek() === ")") this.pos++;
            return { kind: "subref", id };
          }
        }
        return { kind: "null" };
      }

      if (ident === "Array") {
        this.skipWs();
        if (this.peek() === "[") {
          const typeHint = this.parseTypeHint();
          this.skipWs();
          if (this.peek() === "(") {
            this.pos++;
            this.skipWsNl();
            if (this.peek() === "[") {
              const inner = this.parseArray() as {
                kind: "array";
                items: TresValue[];
              };
              this.skipWsNl();
              if (this.peek() === ")") this.pos++;
              return { kind: "typedarray", typeHint, items: inner.items };
            }
            if (this.peek() === ")") this.pos++;
          }
        }
        return { kind: "array", items: [] };
      }

      // Generic constructor call: Name(arg1, arg2, ...)
      this.skipWs();
      if (this.peek() === "(") {
        this.pos++;
        const args: TresValue[] = [];
        while (true) {
          this.skipWsNl();
          if (this.peek() === ")") {
            this.pos++;
            break;
          }
          if (this.peek() === "") break;
          args.push(this.parseValue());
          this.skipWsNl();
          if (this.peek() === ",") this.pos++;
        }
        return { kind: "call", name: ident, args };
      }

      // Bare identifier (shouldn't appear in valid .tres)
      return { kind: "string", value: ident };
    }

    // Unknown character — skip and return null
    this.pos++;
    return { kind: "null" };
  }
}

// ---- Section header parsing ------------------------------------------------

interface SectionHeader {
  type: string;
  attrs: Record<string, string>;
}

function parseSectionHeader(line: string): SectionHeader {
  const inner = line.trim().slice(1, line.trim().lastIndexOf("]"));
  const attrs: Record<string, string> = {};

  let pos = 0;
  while (pos < inner.length && /[a-zA-Z_]/.test(inner[pos])) pos++;
  const type = inner.slice(0, pos);

  while (pos < inner.length) {
    while (pos < inner.length && /[ \t]/.test(inner[pos])) pos++;
    if (pos >= inner.length) break;

    const keyStart = pos;
    while (pos < inner.length && /[a-zA-Z0-9_]/.test(inner[pos])) pos++;
    if (pos === keyStart) {
      pos++;
      continue;
    }
    const key = inner.slice(keyStart, pos);

    while (pos < inner.length && /[ \t]/.test(inner[pos])) pos++;
    if (inner[pos] !== "=") continue;
    pos++;

    while (pos < inner.length && /[ \t]/.test(inner[pos])) pos++;

    let value: string;
    if (inner[pos] === '"') {
      pos++;
      let s = "";
      while (pos < inner.length && inner[pos] !== '"') {
        if (inner[pos] === "\\") {
          pos++;
          s += inner[pos++] ?? "";
        } else {
          s += inner[pos++];
        }
      }
      pos++; // consume closing "
      value = s;
    } else {
      const valStart = pos;
      while (pos < inner.length && !/[ \t]/.test(inner[pos])) pos++;
      value = inner.slice(valStart, pos);
    }

    attrs[key] = value;
  }

  return { type, attrs };
}

// ---- Section body parsing --------------------------------------------------

function parseSectionBody(body: string): Record<string, TresValue> {
  const props: Record<string, TresValue> = {};
  const lines = body.split("\n");

  let currentKey: string | null = null;
  let currentParts: string[] = [];

  const flush = () => {
    if (currentKey === null) return;
    const raw = currentParts.join("\n");
    try {
      const p = new ValueParser(raw.trim());
      props[currentKey] = p.parseValue();
    } catch {
      // ignore unparseable values
    }
    currentKey = null;
    currentParts = [];
  };

  for (const line of lines) {
    // A new property starts when the line begins with identifier = value
    const m = line.match(/^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.*)/);
    if (m) {
      flush();
      currentKey = m[1];
      currentParts = [m[2]];
    } else if (currentKey !== null) {
      currentParts.push(line);
    }
  }

  flush();
  return props;
}

// ---- Main document parser --------------------------------------------------

// A line is a section header if it starts with '[' followed by a letter.
// This distinguishes section headers from array values that begin with '['.
function isSectionHeader(line: string): boolean {
  const t = line.trim();
  return t.startsWith("[") && t.endsWith("]") && /^\[[a-zA-Z_]/.test(t);
}

export function parseTres(text: string): TresFile {
  const lines = text.split("\n");

  const header: TresHeader = { type: "Resource" };
  const extResources: ExtResource[] = [];
  const subResources: SubResource[] = [];
  let resource: Record<string, TresValue> = {};

  type Block = { headerLine: string; bodyLines: string[] };
  const blocks: Block[] = [];
  let bodyLines: string[] = [];

  for (const line of lines) {
    if (isSectionHeader(line)) {
      if (blocks.length > 0) {
        blocks[blocks.length - 1].bodyLines = bodyLines;
      }
      bodyLines = [];
      blocks.push({ headerLine: line.trim(), bodyLines: [] });
    } else if (blocks.length > 0) {
      bodyLines.push(line);
    }
  }
  if (blocks.length > 0) {
    blocks[blocks.length - 1].bodyLines = bodyLines;
  }

  for (const block of blocks) {
    const { type: secType, attrs } = parseSectionHeader(block.headerLine);
    const body = block.bodyLines.join("\n");

    switch (secType) {
      case "gd_resource":
        header.type = attrs.type ?? "Resource";
        if (attrs.script_class) header.scriptClass = attrs.script_class;
        if (attrs.uid) header.uid = attrs.uid;
        if (attrs.format) header.format = parseInt(attrs.format, 10);
        break;

      case "ext_resource":
        extResources.push({
          id: attrs.id ?? "",
          type: attrs.type ?? "",
          path: attrs.path,
          uid: attrs.uid,
        });
        break;

      case "sub_resource":
        subResources.push({
          type: attrs.type ?? "",
          id: attrs.id ?? "",
          props: parseSectionBody(body),
        });
        break;

      case "resource":
        resource = parseSectionBody(body);
        break;
    }
  }

  return { header, extResources, subResources, resource };
}
