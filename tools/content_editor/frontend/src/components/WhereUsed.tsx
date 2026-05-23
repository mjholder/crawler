import { useEffect, useState } from "react";
import { api } from "../api.js";

interface Props {
  uid: string;
  onNavigate?: (path: string) => void;
}

export function WhereUsed({ uid, onNavigate }: Props) {
  const [refs, setRefs] = useState<string[]>([]);

  useEffect(() => {
    api.indexEntry(uid)
      .then((entry) => setRefs(entry.referenced_by))
      .catch(() => setRefs([]));
  }, [uid]);

  if (refs.length === 0) return null;

  return (
    <div style={styles.panel}>
      <div style={styles.heading}>Referenced by</div>
      {refs.map((r) => (
        <button
          key={r}
          style={styles.refBtn}
          onClick={() => onNavigate?.(r)}
          title={r}
        >
          {r.replace("res://", "")}
        </button>
      ))}
    </div>
  );
}

const styles = {
  panel: {
    borderTop: "1px solid #2a2a2a",
    padding: "8px 16px 12px",
    background: "#111",
  },
  heading: { fontSize: 11, color: "#555", marginBottom: 6, textTransform: "uppercase" as const, letterSpacing: 1 },
  refBtn: {
    display: "block",
    background: "none",
    border: "none",
    color: "#88a",
    cursor: "pointer",
    padding: "2px 0",
    fontSize: 12,
    fontFamily: "monospace",
    textAlign: "left" as const,
  },
} as const;
