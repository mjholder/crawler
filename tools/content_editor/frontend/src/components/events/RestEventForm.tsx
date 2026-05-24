interface Props {
  json: Record<string, unknown>;
  onChange: (json: Record<string, unknown>) => void;
}

export function RestEventForm({ json, onChange }: Props) {
  const expr = (json.heal_expression as string) ?? "";

  return (
    <div>
      <label style={styles.label}>heal_expression</label>
      <textarea
        value={expr}
        rows={3}
        onChange={(e) => onChange({ ...json, heal_expression: e.target.value })}
        style={styles.textarea}
        placeholder="e.g. max_health * 0.5"
      />
      <div style={styles.hint}>
        Available variables: <code>max_health</code>, <code>spirit</code>, <code>constitution</code>
      </div>
    </div>
  );
}

const styles = {
  label: { display: "block", fontSize: 12, color: "#999", fontFamily: "monospace", marginBottom: 4 },
  textarea: {
    display: "block",
    width: "100%",
    background: "#222",
    border: "1px solid #444",
    color: "#eee",
    borderRadius: 3,
    padding: "6px 8px",
    fontSize: 13,
    fontFamily: "monospace",
    resize: "vertical" as const,
    outline: "none",
  },
  hint: { fontSize: 11, color: "#555", marginTop: 6 },
} as const;
