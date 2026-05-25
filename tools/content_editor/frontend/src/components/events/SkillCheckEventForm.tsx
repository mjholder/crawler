import { PathPicker } from "./PathPicker.js";

const STAT_OPTIONS = ["STRENGTH", "DEFENSE", "CONSTITUTION", "AGILITY", "SPIRIT", "LUCK"];

interface Rewards { experience?: number; gold?: number }

interface Props {
  json: Record<string, unknown>;
  onChange: (json: Record<string, unknown>) => void;
  dialoguePaths: string[];
  onNavigate?: (path: string) => void;
}

export function SkillCheckEventForm({ json, onChange, dialoguePaths, onNavigate }: Props) {
  const label = (json.label as string) ?? "";
  const name = (json.name as string) ?? "";
  const stat = (json.stat as string) ?? "AGILITY";
  const thresholdExpression = (json.threshold_expression as string) ?? "";
  const onSuccess = (json.on_success as string) ?? "";
  const onFailure = (json.on_failure as string) ?? "";
  const rewardsSuccess = (json.rewards_on_success as Rewards) ?? {};
  const rewardsFailure = (json.rewards_on_failure as Rewards) ?? {};

  function setField(key: string, val: unknown) {
    onChange({ ...json, [key]: val });
  }

  return (
    <div style={styles.root}>
      <Row label="name">
        <input style={styles.input} value={name} onChange={(e) => setField("name", e.target.value)} />
      </Row>
      <Row label="label">
        <input style={styles.input} value={label} onChange={(e) => setField("label", e.target.value)} placeholder="Prompt shown to player" />
      </Row>
      <Row label="stat">
        <select
          style={styles.select}
          value={stat}
          onChange={(e) => setField("stat", e.target.value)}
        >
          {STAT_OPTIONS.map((s) => (
            <option key={s} value={s}>{s}</option>
          ))}
        </select>
      </Row>
      <Row label="threshold_expression">
        <div>
          <textarea
            style={styles.textarea}
            rows={2}
            value={thresholdExpression}
            onChange={(e) => setField("threshold_expression", e.target.value)}
            placeholder="(defaults to stat value — e.g. agility - 10)"
          />
          <div style={styles.hint}>
            Variables: <code>strength</code> <code>defense</code> <code>constitution</code> <code>agility</code> <code>spirit</code> <code>luck</code> <code>max_health</code> <code>health</code>
          </div>
        </div>
      </Row>

      <SectionHeader>On success</SectionHeader>
      <Row label="on_success dialogue">
        <PathPicker value={onSuccess} options={dialoguePaths} onChange={(v) => setField("on_success", v)} onNavigate={onNavigate} />
      </Row>
      <Row label="experience">
        <NumberInput value={rewardsSuccess.experience ?? 0} onChange={(v) => setField("rewards_on_success", { ...rewardsSuccess, experience: v })} />
      </Row>
      <Row label="gold">
        <NumberInput value={rewardsSuccess.gold ?? 0} onChange={(v) => setField("rewards_on_success", { ...rewardsSuccess, gold: v })} />
      </Row>

      <SectionHeader>On failure</SectionHeader>
      <Row label="on_failure dialogue">
        <PathPicker value={onFailure} options={dialoguePaths} onChange={(v) => setField("on_failure", v)} onNavigate={onNavigate} />
      </Row>
      <Row label="experience">
        <NumberInput value={rewardsFailure.experience ?? 0} onChange={(v) => setField("rewards_on_failure", { ...rewardsFailure, experience: v })} />
      </Row>
      <Row label="gold">
        <NumberInput value={rewardsFailure.gold ?? 0} onChange={(v) => setField("rewards_on_failure", { ...rewardsFailure, gold: v })} />
      </Row>
    </div>
  );
}

function NumberInput({ value, onChange }: { value: number; onChange: (v: number) => void }) {
  return (
    <input
      type="number"
      step="1"
      value={value}
      onChange={(e) => onChange(parseInt(e.target.value, 10) || 0)}
      style={{ ...styles.input, width: 100 }}
    />
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

function SectionHeader({ children }: { children: React.ReactNode }) {
  return <div style={styles.section}>{children}</div>;
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
  label: { width: 180, minWidth: 180, fontSize: 12, color: "#999", fontFamily: "monospace" },
  field: { flex: 1, minWidth: 0 },
  section: {
    fontSize: 11,
    color: "#666",
    textTransform: "uppercase" as const,
    letterSpacing: "0.06em",
    padding: "10px 0 4px",
    borderBottom: "1px solid #2a2a2a",
  },
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
  select: {
    background: "#222",
    border: "1px solid #444",
    color: "#eee",
    borderRadius: 3,
    padding: "3px 6px",
    fontSize: 13,
    outline: "none",
  },
  textarea: {
    display: "block" as const,
    width: "100%",
    background: "#222",
    border: "1px solid #444",
    color: "#eee",
    borderRadius: 3,
    padding: "4px 6px",
    fontSize: 13,
    fontFamily: "monospace",
    resize: "vertical" as const,
    outline: "none",
    boxSizing: "border-box" as const,
  },
  hint: { fontSize: 11, color: "#555", marginTop: 4 },
} as const;
