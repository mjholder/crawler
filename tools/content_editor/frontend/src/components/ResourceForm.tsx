import { useEffect, useState, useCallback } from "react";
import type { GameSchema } from "../types/schema.js";
import { getAllProperties } from "../types/schema.js";
import { FIELD_VISIBILITY } from "../types/fieldVisibility.js";
import { api } from "../api.js";
import { FieldRenderer, FormRow } from "./FieldRenderer.js";
import { LineageBuilder } from "./LineageBuilder.js";
import { WhereUsed } from "./WhereUsed.js";

interface Props {
  resPath: string;
  schema: GameSchema;
  onNavigate?: (path: string) => void;
}

type SaveState = "idle" | "saving" | "saved" | "error";

export function ResourceForm({ resPath, schema, onNavigate }: Props) {
  const [data, setData] = useState<Record<string, unknown> | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [dirty, setDirty] = useState(false);
  const [saveState, setSaveState] = useState<SaveState>("idle");
  const [lintErrors, setLintErrors] = useState<Array<{ path: string; message: string }>>([]);

  useEffect(() => {
    setLoading(true);
    setData(null);
    setLoadError(null);
    setDirty(false);
    setSaveState("idle");
    setLintErrors([]);
    api.readResource(resPath)
      .then((d) => setData(d as Record<string, unknown>))
      .catch((e) => setLoadError(String(e)))
      .finally(() => setLoading(false));
  }, [resPath]);

  const updateField = useCallback((name: string, value: unknown) => {
    setData((prev) => prev ? { ...prev, [name]: value } : prev);
    setDirty(true);
    setSaveState("idle");
  }, []);

  const save = useCallback(async () => {
    if (!data) return;
    setSaveState("saving");
    try {
      // Lint before save (non-blocking warning)
      const errors = await api.lintData(data);
      setLintErrors(errors);
      await api.writeResource(resPath, data);
      setSaveState("saved");
      setDirty(false);
      setTimeout(() => setSaveState("idle"), 2000);
    } catch (e) {
      console.error(e);
      setSaveState("error");
    }
  }, [data, resPath]);

  if (loading) return <div style={styles.loading}>Loading…</div>;
  if (loadError) return <div style={styles.loadError}><strong>Failed to load resource</strong><pre style={styles.loadErrorPre}>{loadError}</pre></div>;
  if (!data) return <div style={styles.loading}>No data</div>;

  const meta = data._godot_meta as Record<string, unknown> | undefined;
  const cls = (meta?.class as string) ?? "";
  const allProps = getAllProperties(cls, schema);
  const predicate = FIELD_VISIBILITY[cls];
  const props = predicate ? allProps.filter((p) => predicate(p.name, data)) : allProps;
  const uid = (meta?.uid as string) ?? "";

  return (
    <div style={styles.form}>
      {/* Header */}
      <div style={styles.header}>
        <div>
          <div style={styles.className}>{cls}</div>
          <div style={styles.path}>{resPath}</div>
          {uid && <div style={styles.uid}>{uid}</div>}
        </div>
        <div style={styles.saveRow}>
          {lintErrors.length > 0 && (
            <span style={styles.warnBadge}>{lintErrors.length} warnings</span>
          )}
          <button
            style={{
              ...styles.saveBtn,
              ...(saveState === "saved" ? styles.saveBtnOk : {}),
              ...(saveState === "error" ? styles.saveBtnErr : {}),
              opacity: dirty || saveState === "saving" ? 1 : 0.5,
            }}
            onClick={save}
            disabled={saveState === "saving"}
          >
            {saveState === "saving"
              ? "Saving…"
              : saveState === "saved"
              ? "Saved ✓"
              : saveState === "error"
              ? "Error!"
              : "Save"}
          </button>
        </div>
      </div>

      {/* Lint warnings */}
      {lintErrors.length > 0 && (
        <div style={styles.lintPanel}>
          {lintErrors.map((e, i) => (
            <div key={i} style={styles.lintRow}>
              <span style={styles.lintPath}>{e.path}</span>
              <span style={styles.lintMsg}>{e.message}</span>
            </div>
          ))}
        </div>
      )}

      {/* Fields */}
      <div style={styles.fields}>
        {cls === "PatronSaintData" && (
          <LineageBuilder
            data={data}
            updateField={updateField}
            schema={schema}
            onNavigate={onNavigate}
          />
        )}
        {props.map((prop) => (
          <FormRow key={prop.name} label={prop.name}>
            <FieldRenderer
              prop={prop}
              value={data[prop.name]}
              onChange={(v) => updateField(prop.name, v)}
              schema={schema}
              onNavigate={onNavigate}
              ownerClass={cls}
            />
          </FormRow>
        ))}
      </div>

      {/* Where used */}
      {uid && <WhereUsed uid={uid} onNavigate={onNavigate} />}
    </div>
  );
}

const styles = {
  form: {
    flex: 1,
    display: "flex",
    flexDirection: "column" as const,
    overflow: "hidden",
    background: "#111",
  },
  loading: { padding: 24, color: "#555" },
  loadError: { padding: 24, color: "#f88", fontSize: 13 },
  loadErrorPre: { marginTop: 8, color: "#c88", fontSize: 11, fontFamily: "monospace", whiteSpace: "pre-wrap" as const, background: "#1a0a0a", padding: 10, borderRadius: 4, border: "1px solid #422" },
  header: {
    padding: "12px 16px",
    borderBottom: "1px solid #333",
    background: "#161616",
    display: "flex",
    justifyContent: "space-between",
    alignItems: "flex-start",
  },
  className: { fontSize: 15, fontWeight: 600, color: "#eee" },
  path: { fontSize: 11, color: "#666", marginTop: 2, fontFamily: "monospace" },
  uid: { fontSize: 10, color: "#444", marginTop: 1, fontFamily: "monospace" },
  saveRow: { display: "flex", alignItems: "center", gap: 10 },
  warnBadge: {
    background: "#442200",
    color: "#fa0",
    fontSize: 11,
    padding: "2px 8px",
    borderRadius: 10,
  },
  saveBtn: {
    padding: "6px 16px",
    background: "#2a4a2a",
    border: "1px solid #3a6a3a",
    color: "#8f8",
    cursor: "pointer",
    borderRadius: 4,
    fontSize: 13,
  },
  saveBtnOk: { background: "#1a3a1a", color: "#6f6" },
  saveBtnErr: { background: "#4a1a1a", color: "#f66", border: "1px solid #6a2a2a" },
  fields: {
    flex: 1,
    overflowY: "auto" as const,
    padding: "8px 16px",
  },
  lintPanel: {
    background: "#1a1000",
    borderBottom: "1px solid #443300",
    padding: "6px 16px",
    maxHeight: 120,
    overflowY: "auto" as const,
  },
  lintRow: { display: "flex", gap: 8, marginBottom: 2 },
  lintPath: { color: "#fa0", fontSize: 11, fontFamily: "monospace", flexShrink: 0 },
  lintMsg: { color: "#caa", fontSize: 11 },
} as const;
