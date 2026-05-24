// AST types for Godot .tres resource files

export type TresValue =
  | { kind: "null" }
  | { kind: "bool"; value: boolean }
  | { kind: "int"; value: number }
  | { kind: "float"; value: number }
  | { kind: "string"; value: string }
  | { kind: "stringname"; value: string }
  | { kind: "extref"; id: string }
  | { kind: "subref"; id: string }
  | { kind: "call"; name: string; args: TresValue[] }
  | { kind: "array"; items: TresValue[] }
  | { kind: "typedarray"; typeHint: string; items: TresValue[] }
  | { kind: "dict"; entries: Array<{ key: TresValue; value: TresValue }> };

export interface ExtResource {
  id: string;
  type: string;
  path?: string;
  uid?: string;
}

export interface SubResource {
  type: string;
  id: string;
  props: Record<string, TresValue>;
}

export interface TresHeader {
  type: string;
  scriptClass?: string;
  format?: number;
  uid?: string;
}

export interface TresFile {
  header: TresHeader;
  extResources: ExtResource[];
  subResources: SubResource[];
  resource: Record<string, TresValue>;
}
