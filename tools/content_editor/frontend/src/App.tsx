import { useEffect, useState } from "react";
import type { GameSchema } from "./types/schema.js";
import { api } from "./api.js";
import { Sidebar } from "./components/Sidebar.js";
import { ResourceForm } from "./components/ResourceForm.js";
import { ResourceTable } from "./components/ResourceTable.js";

type ViewMode = "form" | "table";

export function App() {
  const [schema, setSchema] = useState<GameSchema | null>(null);
  const [schemaError, setSchemaError] = useState<string>("");
  const [selectedType, setSelectedType] = useState<string | null>(null);
  const [selectedPath, setSelectedPath] = useState<string>("");
  const [viewMode, setViewMode] = useState<ViewMode>("form");

  useEffect(() => {
    api.schema()
      .then(setSchema)
      .catch((e) => setSchemaError(String(e)));
  }, []);

  if (schemaError) {
    return (
      <div style={styles.errorScreen}>
        <div style={styles.errorTitle}>Schema not found</div>
        <div style={styles.errorMsg}>{schemaError}</div>
        <div style={styles.errorHint}>
          Run <code>npm run schema</code> from{" "}
          <code>tools/content_editor/</code> to generate it, then reload.
        </div>
        <button
          style={styles.retryBtn}
          onClick={() => {
            setSchemaError("");
            api.schema().then(setSchema).catch((e) => setSchemaError(String(e)));
          }}
        >
          Retry
        </button>
      </div>
    );
  }

  if (!schema) {
    return <div style={styles.loading}>Loading schema…</div>;
  }

  return (
    <div style={styles.root}>
      <Sidebar
        selectedType={selectedType}
        onSelectType={setSelectedType}
        selectedPath={selectedPath}
        onSelectPath={setSelectedPath}
      />

      <div style={styles.main}>
        {/* View toggle toolbar */}
        {selectedType && (
          <div style={styles.toolbar}>
            <button
              style={{ ...styles.modeBtn, ...(viewMode === "form" ? styles.modeBtnActive : {}) }}
              onClick={() => setViewMode("form")}
            >
              Form
            </button>
            <button
              style={{ ...styles.modeBtn, ...(viewMode === "table" ? styles.modeBtnActive : {}) }}
              onClick={() => setViewMode("table")}
            >
              Table
            </button>
            <button
              style={styles.refreshBtn}
              title="Refresh schema from Godot"
              onClick={() => {
                api.schemaRefresh().then(setSchema).catch(console.error);
              }}
            >
              ↻ schema
            </button>
          </div>
        )}

        {/* Content area */}
        {!selectedType && (
          <div style={styles.empty}>
            Select a content type from the sidebar.
          </div>
        )}

        {selectedType && viewMode === "table" && (
          <ResourceTable
            cls={selectedType}
            schema={schema}
            onOpenForm={(path) => {
              setSelectedPath(path);
              setViewMode("form");
            }}
          />
        )}

        {selectedType && viewMode === "form" && !selectedPath && (
          <div style={styles.empty}>Select a file from the sidebar, or switch to Table view.</div>
        )}

        {selectedType && viewMode === "form" && selectedPath && (
          <ResourceForm resPath={selectedPath} schema={schema} />
        )}
      </div>
    </div>
  );
}

const styles = {
  root: {
    display: "flex",
    height: "100vh",
    overflow: "hidden",
    background: "#111",
    color: "#eee",
    fontFamily: "system-ui, sans-serif",
  },
  main: {
    flex: 1,
    display: "flex",
    flexDirection: "column" as const,
    overflow: "hidden",
  },
  toolbar: {
    display: "flex",
    gap: 4,
    padding: "6px 12px",
    borderBottom: "1px solid #2a2a2a",
    background: "#161616",
    alignItems: "center",
  },
  modeBtn: {
    padding: "4px 12px",
    background: "none",
    border: "1px solid #333",
    color: "#888",
    cursor: "pointer",
    borderRadius: 3,
    fontSize: 12,
  },
  modeBtnActive: {
    background: "#2a2a4a",
    color: "#fff",
    border: "1px solid #446",
  },
  refreshBtn: {
    marginLeft: "auto",
    padding: "3px 10px",
    background: "none",
    border: "1px solid #333",
    color: "#666",
    cursor: "pointer",
    borderRadius: 3,
    fontSize: 11,
  },
  empty: {
    flex: 1,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    color: "#444",
    fontSize: 14,
  },
  loading: {
    display: "flex",
    height: "100vh",
    alignItems: "center",
    justifyContent: "center",
    color: "#555",
    background: "#111",
    fontFamily: "system-ui",
  },
  errorScreen: {
    display: "flex",
    flexDirection: "column" as const,
    height: "100vh",
    alignItems: "center",
    justifyContent: "center",
    background: "#111",
    color: "#eee",
    fontFamily: "system-ui",
    gap: 12,
    padding: 40,
  },
  errorTitle: { fontSize: 18, fontWeight: 600, color: "#f88" },
  errorMsg: { fontSize: 13, color: "#888", fontFamily: "monospace" },
  errorHint: { fontSize: 13, color: "#aaa", textAlign: "center" as const },
  retryBtn: {
    padding: "6px 16px",
    background: "#333",
    border: "1px solid #555",
    color: "#eee",
    cursor: "pointer",
    borderRadius: 4,
  },
} as const;
