import { useEffect, useState } from "react";
import type { GameSchema, PropDescriptor } from "../types/schema.js";
import { api } from "../api.js";
import { FieldRenderer } from "./FieldRenderer.js";

const SLOTS_PROP: PropDescriptor = {
  name: "slots",
  type: "Array",
  element_type: "FloorSlot",
};

export function FloorSlotBuilder({
  schema,
  onHelp,
  onNavigate,
}: {
  schema: GameSchema;
  onHelp: (anchor: string) => void;
  onNavigate?: (path: string) => void;
}) {
  const [floors, setFloors] = useState<string[]>([]);
  const [selectedFloor, setSelectedFloor] = useState<string>("");
  const [data, setData] = useState<Record<string, unknown> | null>(null);
  const [dirty, setDirty] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    api.listType("DungeonFloorData").then(setFloors).catch(console.error);
  }, []);

  useEffect(() => {
    if (!selectedFloor) { setData(null); return; }
    setData(null);
    setDirty(false);
    api.readResource(selectedFloor)
      .then((d) => setData(d as Record<string, unknown>))
      .catch(console.error);
  }, [selectedFloor]);

  function addSlot() {
    if (!data) return;
    const slots = (data.slots as unknown[] | null) ?? [];
    const newSlot = {
      _godot_meta: {
        class: "FloorSlot",
        script: schema.classes["FloorSlot"]?.script ?? "",
        inline: true,
      },
      type: 1,        // RANDOM_TYPE default
      event_type: 0,  // combat
    };
    setData({ ...data, slots: [...slots, newSlot] });
    setDirty(true);
  }

  async function save() {
    if (!selectedFloor || !data) return;
    setSaving(true);
    try {
      await api.writeResource(selectedFloor, data);
      setDirty(false);
    } catch (e) {
      window.alert(`Save failed: ${e}`);
    } finally {
      setSaving(false);
    }
  }

  const floorName = selectedFloor
    ? (selectedFloor.split("/").pop()?.replace(".tres", "") ?? selectedFloor)
    : "";

  return (
    <div style={styles.root}>
      <div style={styles.header}>
        <span style={styles.title}>Floor Slots</span>
        <select
          value={selectedFloor}
          onChange={(e) => setSelectedFloor(e.target.value)}
          style={styles.floorPicker}
        >
          <option value="">(pick a dungeon floor)</option>
          {floors.map((p) => (
            <option key={p} value={p}>
              {p.split("/").pop()?.replace(".tres", "") ?? p}
            </option>
          ))}
        </select>
        {selectedFloor && data && (
          <>
            <button style={styles.addBtn} onClick={addSlot}>
              + Add Slot
            </button>
            <button
              style={{ ...styles.saveBtn, ...(dirty ? styles.saveBtnDirty : {}) }}
              onClick={save}
              disabled={!dirty || saving}
            >
              {saving ? "Saving…" : dirty ? "Save" : "Saved"}
            </button>
          </>
        )}
      </div>

      {!selectedFloor && (
        <div style={styles.empty}>
          Pick a dungeon floor above to view and edit its slots.
        </div>
      )}

      {selectedFloor && !data && (
        <div style={styles.empty}>Loading…</div>
      )}

      {data && (
        <div style={styles.body}>
          <div style={styles.floorMeta}>{floorName}</div>
          <FieldRenderer
            prop={SLOTS_PROP}
            value={data.slots}
            onChange={(v) => { setData({ ...data, slots: v as unknown[] }); setDirty(true); }}
            schema={schema}
            onHelp={onHelp}
            onNavigate={onNavigate}
          />
        </div>
      )}
    </div>
  );
}

const styles = {
  root: {
    flex: 1,
    display: "flex",
    flexDirection: "column" as const,
    overflow: "hidden",
    background: "#111",
  },
  header: {
    display: "flex",
    gap: 8,
    alignItems: "center",
    padding: "10px 16px",
    borderBottom: "1px solid #2a2a2a",
    background: "#161616",
    flexWrap: "wrap" as const,
  },
  title: {
    fontSize: 14,
    fontWeight: 600,
    color: "#ccc",
    marginRight: 4,
  },
  floorPicker: {
    background: "#222",
    color: "#eee",
    border: "1px solid #444",
    borderRadius: 3,
    padding: "4px 8px",
    fontSize: 13,
    outline: "none",
    flex: 1,
    minWidth: 160,
    maxWidth: 320,
  },
  addBtn: {
    padding: "4px 12px",
    background: "#1a3a1a",
    border: "1px solid #3a6a3a",
    color: "#8f8",
    cursor: "pointer",
    borderRadius: 3,
    fontSize: 12,
  },
  saveBtn: {
    padding: "4px 14px",
    background: "#333",
    border: "1px solid #444",
    color: "#888",
    cursor: "default",
    borderRadius: 3,
    fontSize: 12,
  },
  saveBtnDirty: {
    background: "#2a4a2a",
    border: "1px solid #3a6a3a",
    color: "#8f8",
    cursor: "pointer",
  },
  body: {
    flex: 1,
    overflowY: "auto" as const,
    padding: "12px 16px",
  },
  floorMeta: {
    fontSize: 12,
    color: "#555",
    fontFamily: "monospace",
    marginBottom: 10,
  },
  empty: {
    flex: 1,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    color: "#444",
    fontSize: 14,
  },
} as const;
