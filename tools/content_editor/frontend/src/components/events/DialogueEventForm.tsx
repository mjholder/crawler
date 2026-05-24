import { PathPicker } from "./PathPicker.js";

interface Props {
  json: Record<string, unknown>;
  onChange: (json: Record<string, unknown>) => void;
  dialoguePaths: string[];
  onNavigate?: (path: string) => void;
}

export function DialogueEventForm({ json, onChange, dialoguePaths, onNavigate }: Props) {
  const name = (json.name as string) ?? "";
  const dialogue = (json.dialogue as string) ?? "";

  return (
    <div style={styles.root}>
      <Row label="name">
        <input
          style={styles.input}
          value={name}
          onChange={(e) => onChange({ ...json, name: e.target.value })}
          placeholder="internal name"
        />
      </Row>
      <Row label="dialogue">
        <PathPicker
          value={dialogue}
          options={dialoguePaths}
          onChange={(v) => onChange({ ...json, dialogue: v })}
          onNavigate={onNavigate}
        />
      </Row>
    </div>
  );
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div style={styles.row}>
      <label style={styles.label}>{label}</label>
      <div style={styles.field}>{children}</div>
    </div>
  );
}

const styles = {
  root: { display: "flex", flexDirection: "column" as const, gap: 0 },
  row: {
    display: "flex",
    alignItems: "center",
    padding: "6px 0",
    gap: 8,
    borderBottom: "1px solid #222",
  },
  label: { width: 160, minWidth: 160, fontSize: 12, color: "#999", fontFamily: "monospace" },
  field: { flex: 1, minWidth: 0 },
  input: {
    background: "#222",
    border: "1px solid #444",
    color: "#eee",
    borderRadius: 3,
    padding: "3px 6px",
    fontSize: 13,
    outline: "none",
    width: "100%",
  },
} as const;
