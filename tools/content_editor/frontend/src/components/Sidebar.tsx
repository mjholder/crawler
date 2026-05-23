import { useEffect, useState, useCallback } from "react";
import { api } from "../api.js";
import { CONTENT_TYPES } from "../types/schema.js";

interface Props {
  selectedType: string | null;
  onSelectType: (cls: string) => void;
  selectedPath: string | null;
  onSelectPath: (path: string) => void;
}

export function Sidebar({ selectedType, onSelectType, selectedPath, onSelectPath }: Props) {
  const [files, setFiles] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);

  const refreshFiles = useCallback((cls: string) => {
    setLoading(true);
    api.listType(cls)
      .then(setFiles)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (!selectedType) return;
    refreshFiles(selectedType);
  }, [selectedType, refreshFiles]);

  const handleNew = useCallback(async (cls: string, dir: string) => {
    // Effects section offers multiple concrete types
    let createCls = cls;
    if (cls === "DamageEffect") {
      const pick = window.prompt(
        "Effect type:\n1 DamageEffect\n2 HealEffect\n3 BuffEffect\n4 StatusEffect\n\nEnter number:"
      );
      const map: Record<string, string> = {
        "1": "DamageEffect", "2": "HealEffect", "3": "BuffEffect", "4": "StatusEffect",
      };
      createCls = map[pick?.trim() ?? ""] ?? "DamageEffect";
    }

    const name = window.prompt(`New ${createCls} filename (no extension):`);
    if (!name) return;
    const path = `${dir}${name.replace(/\.tres$/, "")}.tres`;
    try {
      await api.newResource(path, createCls);
      if (selectedType === cls) refreshFiles(cls);
      onSelectPath(path);
    } catch (e) {
      window.alert(`Failed to create: ${e}`);
    }
  }, [selectedType, refreshFiles, onSelectPath]);

  return (
    <aside style={styles.aside}>
      <div style={styles.typeSection}>
        {CONTENT_TYPES.map(({ label, cls, dir }) => (
          <div
            key={cls}
            style={{
              ...styles.typeRow,
              ...(selectedType === cls ? styles.typeRowActive : {}),
            }}
          >
            <button
              style={styles.typeButton}
              onClick={() => { onSelectType(cls); onSelectPath(""); }}
            >
              {label}
            </button>
            <button
              style={styles.newBtn}
              title={`New ${cls}`}
              onClick={(e) => { e.stopPropagation(); handleNew(cls, dir); }}
            >
              +
            </button>
          </div>
        ))}
      </div>

      <div style={styles.fileList}>
        {loading && <div style={styles.hint}>Loading…</div>}
        {!loading && files.length === 0 && selectedType && (
          <div style={styles.hint}>No files found</div>
        )}
        {files.map((p) => {
          const name = p.split("/").pop() ?? p;
          return (
            <button
              key={p}
              title={p}
              style={{
                ...styles.fileButton,
                ...(selectedPath === p ? styles.fileButtonActive : {}),
              }}
              onClick={() => onSelectPath(p)}
            >
              {name.replace(".tres", "")}
            </button>
          );
        })}
      </div>
    </aside>
  );
}

const styles = {
  aside: {
    width: 220,
    minWidth: 220,
    display: "flex",
    flexDirection: "column" as const,
    borderRight: "1px solid #333",
    background: "#1a1a1a",
    overflowY: "auto" as const,
  },
  typeSection: {
    display: "flex",
    flexDirection: "column" as const,
    borderBottom: "1px solid #333",
  },
  typeRow: {
    display: "flex",
    alignItems: "center",
  },
  typeRowActive: {
    background: "#2a2a4a",
  },
  typeButton: {
    flex: 1,
    padding: "10px 14px",
    background: "none",
    border: "none",
    color: "#ccc",
    cursor: "pointer",
    textAlign: "left" as const,
    fontSize: 13,
  },
  newBtn: {
    padding: "0 10px",
    background: "none",
    border: "none",
    color: "#666",
    cursor: "pointer",
    fontSize: 18,
    lineHeight: 1,
    flexShrink: 0,
    height: "100%",
  },
  fileList: {
    flex: 1,
    overflowY: "auto" as const,
    padding: "4px 0",
  },
  fileButton: {
    display: "block",
    width: "100%",
    padding: "6px 14px",
    background: "none",
    border: "none",
    color: "#aaa",
    cursor: "pointer",
    textAlign: "left" as const,
    fontSize: 12,
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap" as const,
  },
  fileButtonActive: {
    background: "#2a3a2a",
    color: "#eee",
  },
  hint: { color: "#555", fontSize: 12, padding: "8px 14px" },
} as const;
