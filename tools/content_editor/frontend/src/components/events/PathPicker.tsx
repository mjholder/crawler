/**
 * A path selector for raw string paths (not Godot {__ref:...} objects).
 * Used by event forms for dialogue/scene references stored as plain strings in JSON.
 */
interface Props {
  value: string;
  options: string[];
  onChange: (path: string) => void;
  onNavigate?: (path: string) => void;
  placeholder?: string;
}

export function PathPicker({ value, options, onChange, onNavigate, placeholder }: Props) {
  const allOptions = value && !options.includes(value) ? [value, ...options] : options;

  return (
    <div style={styles.row}>
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        style={styles.select}
      >
        <option value="">{placeholder ?? "(none)"}</option>
        {allOptions.map((p) => (
          <option key={p} value={p}>
            {p.split("/").pop() ?? p}
          </option>
        ))}
      </select>
      {value && onNavigate && (
        <button
          style={styles.navBtn}
          title={`Navigate to ${value}`}
          onClick={() => onNavigate(value)}
        >
          →
        </button>
      )}
    </div>
  );
}

const styles = {
  row: { display: "flex", gap: 4, alignItems: "center" },
  select: {
    flex: 1,
    background: "#222",
    border: "1px solid #444",
    color: "#eee",
    borderRadius: 3,
    padding: "3px 6px",
    fontSize: 13,
    outline: "none",
    minWidth: 0,
  },
  navBtn: {
    padding: "2px 7px",
    background: "#333",
    border: "1px solid #444",
    color: "#aaa",
    cursor: "pointer",
    borderRadius: 3,
    fontSize: 13,
    flexShrink: 0,
  },
} as const;
