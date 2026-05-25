import { useEffect, useRef, useState } from "react";
import { api } from "../../api.js";
import { CombatEventForm } from "./CombatEventForm.js";
import { SkillCheckEventForm } from "./SkillCheckEventForm.js";
import { RestEventForm } from "./RestEventForm.js";
import { DialogueEventForm } from "./DialogueEventForm.js";

const DEFAULT_JSON: Record<string, unknown> = {
  CombatEventData: { waves: [], rewards: {} },
  BossEventData: { waves: [], dialogue_triggers: {}, rewards: {} },
  DialogueEventData: { name: "", dialogue: "" },
  SkillCheckEventData: { name: "", label: "", stat: "AGILITY", threshold_expression: "", rewards_on_success: {}, rewards_on_failure: {}, on_success: "", on_failure: "" },
  RestEventData: { heal_expression: "max_health * 0.5" },
};

interface Props {
  resPath: string;
  onNavigate?: (path: string) => void;
}

export function EventEditor({ resPath, onNavigate }: Props) {
  const [tresData, setTresData] = useState<Record<string, unknown> | null>(null);
  const [json, setJson] = useState<Record<string, unknown> | null>(null);
  const [displayName, setDisplayName] = useState("");
  const [eventPath, setEventPath] = useState("");
  const [dialoguePaths, setDialoguePaths] = useState<string[]>([]);
  const [scenePaths, setScenePaths] = useState<string[]>([]);
  const [dirty, setDirty] = useState(false);
  const [status, setStatus] = useState("");
  const initializing = useRef(false);

  // Load dialogue paths + scene paths once
  useEffect(() => {
    api.listDialogues().then(setDialoguePaths).catch(() => {});
    api.listAssets("PackedScene").then(setScenePaths).catch(() => {});
  }, []);

  // Load on resPath change
  useEffect(() => {
    setTresData(null);
    setJson(null);
    setDisplayName("");
    setEventPath("");
    setDirty(false);
    setStatus("");
    initializing.current = false;

    api.readResource(resPath).then(async (raw) => {
      const t = raw as Record<string, unknown>;
      const cls = (t._godot_meta as Record<string, unknown>)?.class as string ?? "";
      const dn = (t.display_name as string) ?? "";
      let ep = (t.event_path as string) ?? "";

      setTresData(t);
      setDisplayName(dn);

      if (!ep) {
        initializing.current = true;
        ep = resPath.replace(/\.tres$/, ".json");
        const blank = DEFAULT_JSON[cls] ?? {};
        await api.writeEvent(ep, blank);
        await api.writeResource(resPath, { ...t, event_path: ep });
        setTresData({ ...t, event_path: ep });
        setEventPath(ep);
        setJson(blank as Record<string, unknown>);
        initializing.current = false;
        return;
      }

      setEventPath(ep);
      api.readEvent(ep).then((data) => {
        setJson(data as Record<string, unknown>);
      }).catch(() => setStatus("Failed to load event JSON"));
    }).catch(() => setStatus("Failed to load resource"));
  }, [resPath]);

  async function save() {
    if (!json || !tresData) return;
    setStatus("Saving…");
    try {
      await api.writeEvent(eventPath, json);
      if (displayName !== tresData.display_name || eventPath !== tresData.event_path) {
        const updated = { ...tresData, display_name: displayName, event_path: eventPath };
        await api.writeResource(resPath, updated);
        setTresData(updated);
      }
      setDirty(false);
      setStatus("Saved ✓");
      setTimeout(() => setStatus(""), 2000);
    } catch (e) {
      setStatus("Error: " + String(e));
    }
  }

  function updateJson(updated: Record<string, unknown>) {
    setJson(updated);
    setDirty(true);
    if (status === "Saved ✓") setStatus("");
  }

  const cls = (tresData?._godot_meta as Record<string, unknown>)?.class as string ?? "";

  if (!tresData) return <div style={styles.loading}>Loading…</div>;
  if (!json) return <div style={styles.loading}>Loading event data…</div>;

  return (
    <div style={styles.root}>
      {/* Header */}
      <div style={styles.header}>
        <div style={styles.headerLeft}>
          <input
            style={styles.nameInput}
            value={displayName}
            onChange={(e) => { setDisplayName(e.target.value); setDirty(true); }}
            placeholder="Display name"
          />
          <div style={styles.pathLine}>{eventPath || resPath}</div>
        </div>
        <div style={styles.headerRight}>
          {status && <span style={status.startsWith("Error") ? styles.statusErr : styles.statusOk}>{status}</span>}
          <button
            style={{ ...styles.saveBtn, opacity: dirty ? 1 : 0.5 }}
            onClick={save}
          >
            Save
          </button>
        </div>
      </div>

      {/* Form area */}
      <div style={styles.body}>
        {(cls === "CombatEventData" || cls === "BossEventData") && (
          <CombatEventForm
            json={json}
            onChange={updateJson}
            isBoss={cls === "BossEventData"}
            dialoguePaths={dialoguePaths}
            scenePaths={scenePaths}
            onNavigate={onNavigate}
          />
        )}
        {cls === "SkillCheckEventData" && (
          <SkillCheckEventForm
            json={json}
            onChange={updateJson}
            dialoguePaths={dialoguePaths}
            onNavigate={onNavigate}
          />
        )}
        {cls === "RestEventData" && (
          <RestEventForm json={json} onChange={updateJson} />
        )}
        {cls === "DialogueEventData" && (
          <DialogueEventForm
            json={json}
            onChange={updateJson}
            dialoguePaths={dialoguePaths}
            onNavigate={onNavigate}
          />
        )}
      </div>
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
  loading: { padding: 24, color: "#555" },
  header: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    padding: "10px 16px",
    borderBottom: "1px solid #333",
    background: "#161616",
    gap: 12,
  },
  headerLeft: { display: "flex", flexDirection: "column" as const, gap: 4, minWidth: 0 },
  headerRight: { display: "flex", alignItems: "center", gap: 10, flexShrink: 0 },
  nameInput: {
    background: "#222",
    border: "1px solid #444",
    color: "#eee",
    borderRadius: 3,
    padding: "4px 8px",
    fontSize: 14,
    fontWeight: 600,
    outline: "none",
    width: 280,
  },
  pathLine: { fontSize: 11, color: "#555", fontFamily: "monospace" },
  saveBtn: {
    padding: "6px 16px",
    background: "#2a4a2a",
    border: "1px solid #3a6a3a",
    color: "#8f8",
    cursor: "pointer",
    borderRadius: 4,
    fontSize: 13,
  },
  statusOk: { fontSize: 12, color: "#8f8" },
  statusErr: { fontSize: 12, color: "#f66" },
  body: {
    flex: 1,
    overflowY: "auto" as const,
    padding: "16px",
  },
} as const;
