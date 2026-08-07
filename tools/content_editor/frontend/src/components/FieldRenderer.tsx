/**
 * Schema-driven field widgets.
 *
 * Each widget receives the current value, a change callback, and the field
 * descriptor.  They must not write to disk themselves — the parent form
 * accumulates changes and saves on demand.
 */
import { useState, useEffect } from "react";
import type { PropDescriptor, GameSchema } from "../types/schema.js";
import { getAllProperties } from "../types/schema.js";
import { FIELD_VISIBILITY, getFieldDirOverride, getWidgetOverride } from "../types/fieldVisibility.js";
import { api } from "../api.js";

const BUILTIN_ASSET_TYPES = new Set(["Texture2D", "AudioStream", "PackedScene", "SpriteFrames"]);

/** Returns the set of concrete subclass names for a given base class. */
function getConcreteSubclasses(baseCls: string, schema: GameSchema): string[] {
  return Object.entries(schema.classes)
    .filter(([, desc]) => {
      let cur = desc.extends;
      while (cur) {
        if (cur === baseCls) return true;
        cur = schema.classes[cur]?.extends ?? "";
      }
      return false;
    })
    .map(([name]) => name);
}

export interface FieldProps {
  prop: PropDescriptor;
  value: unknown;
  onChange: (newValue: unknown) => void;
  schema: GameSchema;
  depth?: number;
  onNavigate?: (path: string) => void;
  onHelp?: (anchor: string) => void;
  dirOverride?: string;
  /** Class that owns this prop; enables per-field widget overrides. */
  ownerClass?: string;
}

export function FieldRenderer({ prop, value, onChange, schema, depth = 0, onNavigate, onHelp, dirOverride, ownerClass }: FieldProps) {
  if (depth > 4) return <span style={{ color: "#888" }}>[deep]</span>;

  // Per-field widget overrides (keyed by ClassName.propName) win over the
  // structural type dispatch below.
  const override = getWidgetOverride(ownerClass, prop.name);
  if (override === "subscriptions") {
    return (
      <SubscriptionsField
        value={value as Record<string, unknown> | null}
        onChange={onChange}
        schema={schema}
        depth={depth}
        onNavigate={onNavigate}
        onHelp={onHelp}
      />
    );
  }

  switch (prop.type) {
    case "bool":
      return <BoolField value={value as boolean} onChange={onChange} />;

    case "int":
    case "float":
      return (
        <NumberField
          value={value as number}
          isFloat={prop.type === "float"}
          onChange={onChange}
        />
      );

    case "String":
      return <StringField value={value as string} onChange={onChange} multiline={prop.name === "description"} />;

    case "StringName":
      return <StringNameField value={value} onChange={onChange} />;

    case "enum":
      return (
        <EnumField
          value={value as number}
          onChange={onChange}
          enumRef={prop.enum_ref}
          enumValues={prop.enum_values}
          schema={schema}
        />
      );

    case "flags":
      return (
        <FlagsField
          value={value as number}
          onChange={onChange}
          enumRef={prop.enum_ref}
          flagValues={prop.flag_values}
          schema={schema}
        />
      );

    case "Dictionary":
      if (prop.key_type?.startsWith("Enums.")) {
        return (
          <StatDictField
            value={value as Record<string, unknown> | null}
            onChange={onChange}
            keyEnumRef={prop.key_type}
            schema={schema}
          />
        );
      }
      return <JsonField value={value} onChange={onChange} label="Dictionary" />;

    case "Array":
      return (
        <ArrayField
          value={value as unknown[] | null}
          onChange={onChange}
          elementType={prop.element_type ?? ""}
          schema={schema}
          depth={depth}
          onNavigate={onNavigate}
          onHelp={onHelp}
        />
      );

    case "Resource":
      return (
        <ResourceRefField
          value={value}
          onChange={onChange}
          resourceType={prop.resource_type ?? ""}
          schema={schema}
          depth={depth}
          onNavigate={onNavigate}
          onHelp={onHelp}
          dirOverride={dirOverride}
        />
      );

    default:
      return <JsonField value={value} onChange={onChange} label={prop.type} />;
  }
}

// --- Primitives ------------------------------------------------------------

function BoolField({ value, onChange }: { value: boolean; onChange: (v: boolean) => void }) {
  return (
    <input
      type="checkbox"
      checked={!!value}
      onChange={(e) => onChange(e.target.checked)}
      style={fieldStyle}
    />
  );
}

function NumberField({
  value,
  isFloat,
  onChange,
}: {
  value: number;
  isFloat: boolean;
  onChange: (v: number) => void;
}) {
  return (
    <input
      type="number"
      step={isFloat ? "any" : "1"}
      value={value ?? ""}
      onChange={(e) =>
        onChange(isFloat ? parseFloat(e.target.value) : parseInt(e.target.value, 10))
      }
      style={{ ...fieldStyle, width: 120 }}
    />
  );
}

function StringField({
  value,
  onChange,
  multiline,
}: {
  value: string;
  onChange: (v: string) => void;
  multiline?: boolean;
}) {
  if (multiline) {
    return (
      <textarea
        value={value ?? ""}
        rows={3}
        onChange={(e) => onChange(e.target.value)}
        style={{ ...fieldStyle, width: "100%", resize: "vertical" }}
      />
    );
  }
  return (
    <input
      type="text"
      value={value ?? ""}
      onChange={(e) => onChange(e.target.value)}
      style={{ ...fieldStyle, width: "100%" }}
    />
  );
}

function StringNameField({ value, onChange }: { value: unknown; onChange: (v: unknown) => void }) {
  const current = (value as { __sn?: string } | null)?.__sn ?? (typeof value === "string" ? value : "");
  return (
    <input
      type="text"
      value={current}
      onChange={(e) => onChange({ __sn: e.target.value })}
      style={{ ...fieldStyle, fontFamily: "monospace", width: "100%" }}
    />
  );
}

// --- Enum ------------------------------------------------------------------

function EnumField({
  value,
  onChange,
  enumRef,
  enumValues,
  schema,
}: {
  value: number;
  onChange: (v: number) => void;
  enumRef?: string;
  enumValues?: Record<string, number>;
  schema: GameSchema;
}) {
  const entries = enumRef ? schema.enums[enumRef] : enumValues ?? {};
  const firstVal = Object.values(entries ?? {})[0] ?? 0;
  return (
    <select
      value={value ?? firstVal}
      onChange={(e) => onChange(parseInt(e.target.value, 10))}
      style={fieldStyle}
    >
      {Object.entries(entries ?? {}).map(([name, int]) => (
        <option key={int} value={int}>
          {name} ({int})
        </option>
      ))}
    </select>
  );
}

// --- Flags (bitmask) -------------------------------------------------------

function FlagsField({
  value,
  onChange,
  enumRef,
  flagValues,
  schema,
}: {
  value: number;
  onChange: (v: number) => void;
  enumRef?: string;
  flagValues?: Record<string, number>;
  schema: GameSchema;
}) {
  const entries = enumRef ? schema.enums[enumRef] : flagValues ?? {};
  const mask = value ?? 0;
  return (
    <div style={{ display: "flex", flexWrap: "wrap", gap: 10 }}>
      {Object.entries(entries ?? {}).map(([name, bit]) => (
        <label key={bit} style={{ display: "flex", alignItems: "center", gap: 4, fontSize: 13, color: "#ccc" }}>
          <input
            type="checkbox"
            checked={(mask & bit) === bit}
            onChange={(e) => onChange(e.target.checked ? mask | bit : mask & ~bit)}
          />
          {name}
        </label>
      ))}
    </div>
  );
}

// --- Stat/enum-keyed dictionary -------------------------------------------

function StatDictField({
  value,
  onChange,
  keyEnumRef,
  schema,
}: {
  value: Record<string, unknown> | null;
  onChange: (v: unknown) => void;
  keyEnumRef: string;
  schema: GameSchema;
}) {
  const enumEntries = schema.enums[keyEnumRef] ?? {};
  const current = (value ?? {}) as Record<string, unknown>;

  // Present keys: numeric strings that map to a known enum value
  const validIntKeys = new Set(Object.values(enumEntries).map(String));
  const presentKeys = Object.keys(current).filter(
    (k) => k !== "__key_type" && validIntKeys.has(k)
  );

  function emitUpdate(keys: string[], vals: Record<string, unknown>) {
    const next: Record<string, unknown> = { __key_type: "int" };
    for (const k of keys) next[k] = vals[k];
    onChange(next);
  }

  function updateVal(key: string, raw: string) {
    const next: Record<string, unknown> = { ...current };
    next[key] = parseInt(raw) || 0;
    emitUpdate(presentKeys, next);
  }

  function changeStat(oldKey: string, newKey: string) {
    const val = current[oldKey] ?? 0;
    const next: Record<string, unknown> = {};
    for (const k of presentKeys) next[k] = current[k];
    delete next[oldKey];
    next[newKey] = val;
    const newKeys = presentKeys.map((k) => (k === oldKey ? newKey : k));
    emitUpdate(newKeys, next);
  }

  function remove(key: string) {
    const next: Record<string, unknown> = {};
    for (const k of presentKeys) next[k] = current[k];
    delete next[key];
    emitUpdate(presentKeys.filter((k) => k !== key), next);
  }

  function addEntry() {
    const used = new Set(presentKeys);
    const available = Object.values(enumEntries)
      .map(String)
      .filter((v) => !used.has(v));
    if (available.length === 0) return;
    available.sort((a, b) => parseInt(a) - parseInt(b));
    const newKey = available[0];
    const next: Record<string, unknown> = {};
    for (const k of presentKeys) next[k] = current[k];
    next[newKey] = 0;
    emitUpdate([...presentKeys, newKey], next);
  }

  const allUsed = Object.values(enumEntries).every((v) => presentKeys.includes(String(v)));

  return (
    <div>
      {presentKeys.map((k) => {
        const numVal = typeof current[k] === "number" ? (current[k] as number) : 0;
        const usedOthers = new Set(presentKeys.filter((pk) => pk !== k));
        return (
          <div key={k} style={{ display: "flex", gap: 6, alignItems: "center", marginBottom: 4 }}>
            <select
              value={k}
              onChange={(e) => changeStat(k, e.target.value)}
              style={fieldStyle}
            >
              {Object.entries(enumEntries)
                .filter(([, v]) => !usedOthers.has(String(v)) || String(v) === k)
                .map(([name, v]) => (
                  <option key={v} value={String(v)}>
                    {name}
                  </option>
                ))}
            </select>
            <input
              type="number"
              step="1"
              value={numVal}
              onChange={(e) => updateVal(k, e.target.value)}
              style={{ ...fieldStyle, width: 80 }}
            />
            <button style={styles.removeBtn} onClick={() => remove(k)}>
              ×
            </button>
          </div>
        );
      })}
      {!allUsed && (
        <button style={styles.addBtn} onClick={addEntry}>
          + Add stat
        </button>
      )}
    </div>
  );
}

// --- Subscriptions (StringName signal -> Effect) --------------------------

function SubscriptionsField({
  value,
  onChange,
  schema,
  depth,
  onNavigate,
  onHelp,
}: {
  value: Record<string, unknown> | null;
  onChange: (v: unknown) => void;
  schema: GameSchema;
  depth: number;
  onNavigate?: (path: string) => void;
  onHelp?: (anchor: string) => void;
}) {
  const signals = schema.lifecycle_signals ?? [];
  const current = (value ?? {}) as Record<string, unknown>;
  // Present signal keys are everything except the envelope's __key_type marker.
  const presentKeys = Object.keys(current).filter((k) => k !== "__key_type");

  function emitUpdate(keys: string[], vals: Record<string, unknown>) {
    const next: Record<string, unknown> = { __key_type: "StringName" };
    for (const k of keys) next[k] = vals[k];
    onChange(next);
  }

  function updateEffect(key: string, effect: unknown) {
    emitUpdate(presentKeys, { ...current, [key]: effect });
  }

  function changeSignal(oldKey: string, newKey: string) {
    if (newKey === oldKey || presentKeys.includes(newKey)) return;
    const next: Record<string, unknown> = {};
    for (const k of presentKeys) next[k === oldKey ? newKey : k] = current[k];
    emitUpdate(
      presentKeys.map((k) => (k === oldKey ? newKey : k)),
      next
    );
  }

  function remove(key: string) {
    const next: Record<string, unknown> = { ...current };
    delete next[key];
    emitUpdate(presentKeys.filter((k) => k !== key), next);
  }

  function addEntry() {
    const available = signals.filter((s) => !presentKeys.includes(s));
    if (available.length === 0) return;
    emitUpdate([...presentKeys, available[0]], { ...current, [available[0]]: null });
  }

  const allUsed = signals.length > 0 && signals.every((s) => presentKeys.includes(s));

  return (
    <div style={{ border: "1px solid #333", borderRadius: 4, overflow: "hidden" }}>
      {presentKeys.map((key) => {
        const usedOthers = new Set(presentKeys.filter((k) => k !== key));
        return (
          <div key={key} style={styles.subRow}>
            <select
              value={key}
              onChange={(e) => changeSignal(key, e.target.value)}
              style={{ ...fieldStyle, flexShrink: 0 }}
            >
              {/* keep the current value selectable even if it's no longer a known signal */}
              {!signals.includes(key) && <option value={key}>{key} (unknown)</option>}
              {signals
                .filter((s) => !usedOthers.has(s))
                .map((s) => (
                  <option key={s} value={s}>
                    {s}
                  </option>
                ))}
            </select>
            <span style={{ color: "#555", flexShrink: 0 }}>→</span>
            <div style={{ flex: 1, minWidth: 0 }}>
              <ResourceRefField
                value={current[key]}
                onChange={(v) => updateEffect(key, v)}
                resourceType="Effect"
                schema={schema}
                depth={depth + 1}
                onNavigate={onNavigate}
                onHelp={onHelp}
              />
            </div>
            <button style={styles.removeBtn} onClick={() => remove(key)}>×</button>
          </div>
        );
      })}
      {!allUsed && (
        <button style={styles.addBtn} onClick={addEntry}>
          + Add subscription
        </button>
      )}
      {signals.length === 0 && (
        <div style={{ color: "#a70", fontSize: 11, padding: "4px 6px" }}>
          No lifecycle signals in schema — run <code>make schema</code>.
        </div>
      )}
    </div>
  );
}

// --- Array -----------------------------------------------------------------

function ArrayField({
  value,
  onChange,
  elementType,
  schema,
  depth,
  onNavigate,
  onHelp,
}: {
  value: unknown[] | null;
  onChange: (v: unknown[]) => void;
  elementType: string;
  schema: GameSchema;
  depth: number;
  onNavigate?: (path: string) => void;
  onHelp?: (anchor: string) => void;
}) {
  const arr = value ?? [];

  function updateAt(i: number, newVal: unknown) {
    const next = [...arr];
    next[i] = newVal;
    onChange(next);
  }

  function remove(i: number) {
    onChange(arr.filter((_, idx) => idx !== i));
  }

  const elementProp: PropDescriptor = {
    name: "item",
    type: isResourceClass(elementType, schema) ? "Resource" : "String",
    resource_type: elementType,
  };

  return (
    <div style={{ border: "1px solid #333", borderRadius: 4, overflow: "hidden" }}>
      {arr.map((item, i) => (
        <div key={i} style={styles.arrayRow}>
          <span style={styles.arrayIndex}>{i}</span>
          <div style={{ flex: 1 }}>
            <FieldRenderer
              prop={elementProp}
              value={item}
              onChange={(v) => updateAt(i, v)}
              schema={schema}
              depth={depth + 1}
              onNavigate={onNavigate}
              onHelp={onHelp}
            />
          </div>
          <button style={styles.removeBtn} onClick={() => remove(i)}>×</button>
        </div>
      ))}
      <button style={styles.addBtn} onClick={() => onChange([...arr, null])}>
        + Add
      </button>
    </div>
  );
}

// --- Resource ref picker ---------------------------------------------------

function ResourceRefField({
  value,
  onChange,
  resourceType,
  schema,
  depth,
  onNavigate,
  onHelp,
  dirOverride,
}: {
  value: unknown;
  onChange: (v: unknown) => void;
  resourceType: string;
  schema: GameSchema;
  depth: number;
  onNavigate?: (path: string) => void;
  onHelp?: (anchor: string) => void;
  dirOverride?: string;
}) {
  const [options, setOptions] = useState<string[]>([]);
  const isBuiltin = BUILTIN_ASSET_TYPES.has(resourceType);

  const isRef = !!(value && typeof value === "object" && "__ref" in (value as object));
  const isInline = !!(value && typeof value === "object" && "_godot_meta" in (value as object));
  const currentRef = isRef ? (value as { __ref: string }).__ref : "";

  useEffect(() => {
    if (dirOverride) {
      api.listResourcesInDir(dirOverride).then(setOptions).catch(() => setOptions([]));
      return;
    }
    if (!resourceType) return;
    const fetch = isBuiltin
      ? api.listAssets(resourceType)
      : api.listType(resourceType);
    fetch.then(setOptions).catch(() => setOptions([]));
  }, [resourceType, isBuiltin, dirOverride]);

  // If the value is an inline resource, render the inline editor immediately
  if (isInline) {
    return (
      <InlineResourceEditor
        value={value}
        onChange={onChange}
        schema={schema}
        depth={depth}
        onDetach={() => onChange(null)}
        onNavigate={onNavigate}
        onHelp={onHelp}
      />
    );
  }

  // Build dropdown options; prepend current ref if it's not in the fetched list
  const allOptions =
    currentRef && !options.includes(currentRef)
      ? [currentRef, ...options]
      : options;

  function handleInlineClick() {
    const subclasses = getConcreteSubclasses(resourceType, schema);
    let chosenCls = resourceType;
    if (subclasses.length > 0) {
      const prompt = subclasses.map((s, i) => `${i + 1}. ${s}`).join("\n");
      const pick = window.prompt(`Choose type:\n${prompt}\n\nEnter number:`);
      const idx = parseInt(pick?.trim() ?? "0") - 1;
      chosenCls = subclasses[idx] ?? resourceType;
    }
    onChange({
      _godot_meta: {
        class: chosenCls,
        script: schema.classes[chosenCls]?.script ?? "",
        inline: true,
      },
    });
  }

  return (
    <div style={{ display: "flex", gap: 6, alignItems: "center", flexWrap: "wrap" }}>
      <select
        value={currentRef}
        onChange={(e) => {
          const path = e.target.value;
          if (path === "") onChange(null);
          else onChange({ __ref: path });
        }}
        style={{ ...fieldStyle, flex: 1, minWidth: 0 }}
      >
        <option value="">(none)</option>
        {allOptions.map((p) => (
          <option key={p} value={p}>
            {p.split("/").pop()?.replace(".tres", "") ?? p}
          </option>
        ))}
      </select>
      {currentRef && onNavigate && (
        <button
          style={styles.smallBtn}
          title={`Navigate to ${currentRef}`}
          onClick={() => onNavigate(currentRef)}
        >
          →
        </button>
      )}
      {!isBuiltin && (
        <button
          style={styles.smallBtn}
          title="Inline (embed as sub-resource)"
          onClick={handleInlineClick}
        >
          inline
        </button>
      )}
    </div>
  );
}

function InlineResourceEditor({
  value,
  onChange,
  schema,
  depth,
  onDetach,
  onNavigate,
  onHelp,
}: {
  value: unknown;
  onChange: (v: unknown) => void;
  schema: GameSchema;
  depth: number;
  onDetach: () => void;
  onNavigate?: (path: string) => void;
  onHelp?: (anchor: string) => void;
}) {
  const data = value as Record<string, unknown>;
  const cls = ((data._godot_meta as Record<string, unknown>)?.class as string) ?? "";
  const allProps = getAllProperties(cls, schema);
  const predicate = FIELD_VISIBILITY[cls];
  const props = predicate ? allProps.filter((p) => predicate(p.name, data)) : allProps;

  function updateField(name: string, val: unknown) {
    onChange({ ...data, [name]: val });
  }

  return (
    <div style={styles.inlineBox}>
      <div style={styles.inlineHeader}>
        <span style={{ color: "#aaa", fontSize: 11 }}>[inline: {cls}]</span>
        <button style={styles.smallBtn} onClick={onDetach}>
          link instead
        </button>
      </div>
      {props.map((p) => (
        <FormRow
          key={p.name}
          label={p.name}
          helpAnchor={cls === "FloorSlot" && p.name === "type" ? "floorslot" : undefined}
          onHelp={onHelp}
        >
          <FieldRenderer
            prop={p}
            value={data[p.name]}
            onChange={(v) => updateField(p.name, v)}
            schema={schema}
            depth={depth + 1}
            onNavigate={onNavigate}
            onHelp={onHelp}
            dirOverride={getFieldDirOverride(cls, p.name)}
            ownerClass={cls}
          />
        </FormRow>
      ))}
    </div>
  );
}

// --- Misc ------------------------------------------------------------------

function JsonField({
  value,
  onChange,
  label,
}: {
  value: unknown;
  onChange: (v: unknown) => void;
  label: string;
}) {
  const [text, setText] = useState(JSON.stringify(value, null, 2));
  const [error, setError] = useState("");

  return (
    <div>
      <span style={{ color: "#666", fontSize: 10 }}>{label} (raw JSON)</span>
      <textarea
        value={text}
        rows={4}
        onChange={(e) => {
          setText(e.target.value);
          try {
            onChange(JSON.parse(e.target.value));
            setError("");
          } catch {
            setError("invalid JSON");
          }
        }}
        style={{ ...fieldStyle, width: "100%", fontFamily: "monospace", fontSize: 11 }}
      />
      {error && <span style={{ color: "#f66", fontSize: 11 }}>{error}</span>}
    </div>
  );
}

export function FormRow({
  label,
  children,
  helpAnchor,
  onHelp,
}: {
  label: string;
  children: React.ReactNode;
  helpAnchor?: string;
  onHelp?: (anchor: string) => void;
}) {
  return (
    <div style={styles.row}>
      <label style={styles.label}>
        {label}
        {helpAnchor && onHelp && (
          <button
            style={styles.helpHintBtn}
            onClick={() => onHelp(helpAnchor)}
            title="Open help"
          >
            ?
          </button>
        )}
      </label>
      <div style={styles.fieldWrap}>{children}</div>
    </div>
  );
}

function isResourceClass(name: string, schema: GameSchema): boolean {
  if (!name) return false;
  return name in schema.classes;
}

// --- Styles ----------------------------------------------------------------

const fieldStyle: React.CSSProperties = {
  background: "#222",
  color: "#eee",
  border: "1px solid #444",
  borderRadius: 3,
  padding: "3px 6px",
  fontSize: 13,
  outline: "none",
};

const styles = {
  row: {
    display: "flex",
    alignItems: "flex-start",
    padding: "4px 0",
    gap: 8,
    borderBottom: "1px solid #222",
  },
  label: {
    width: 180,
    minWidth: 180,
    color: "#999",
    fontSize: 12,
    paddingTop: 4,
    fontFamily: "monospace",
  },
  fieldWrap: {
    flex: 1,
    minWidth: 0,
  },
  arrayRow: {
    display: "flex",
    alignItems: "center",
    gap: 6,
    padding: "4px 6px",
    borderBottom: "1px solid #2a2a2a",
  },
  subRow: {
    display: "flex",
    alignItems: "center",
    gap: 6,
    padding: "4px 6px",
    borderBottom: "1px solid #2a2a2a",
  },
  arrayIndex: {
    color: "#555",
    fontSize: 11,
    width: 20,
    textAlign: "right" as const,
    flexShrink: 0,
  },
  helpHintBtn: {
    marginLeft: 4,
    padding: "0 3px",
    background: "none",
    border: "none",
    color: "#7af",
    cursor: "pointer",
    fontSize: 10,
    fontWeight: 600,
    verticalAlign: "middle",
    lineHeight: 1,
  },
  removeBtn: {
    background: "none",
    border: "none",
    color: "#844",
    cursor: "pointer",
    fontSize: 16,
    lineHeight: 1,
    padding: "0 4px",
  },
  addBtn: {
    display: "block",
    width: "100%",
    padding: "6px",
    background: "#222",
    border: "none",
    color: "#888",
    cursor: "pointer",
    fontSize: 12,
    textAlign: "left" as const,
  },
  smallBtn: {
    padding: "2px 6px",
    background: "#333",
    border: "1px solid #444",
    color: "#aaa",
    cursor: "pointer",
    borderRadius: 3,
    fontSize: 11,
  },
  inlineBox: {
    border: "1px solid #334",
    borderRadius: 4,
    padding: "6px 8px",
    background: "#191928",
    marginTop: 4,
  },
  inlineHeader: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 4,
  },
} as const;
