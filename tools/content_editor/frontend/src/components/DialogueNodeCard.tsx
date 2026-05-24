import { Handle, Position } from "@xyflow/react";
import type { NodeProps } from "@xyflow/react";
import type { DialogueNode } from "../dialogue/types.js";

interface NodeData {
  node: DialogueNode;
  nodeId: string;
  selected: boolean;
}

export function DialogueNodeCard({ data }: NodeProps) {
  const { node, selected } = data as unknown as NodeData;

  const truncate = (s: string, max: number) =>
    s.length > max ? s.slice(0, max) + "…" : s;

  return (
    <div
      style={{
        ...styles.card,
        ...(selected ? styles.cardSelected : {}),
      }}
    >
      {/* Input handle — every node accepts incoming connections */}
      <Handle type="target" position={Position.Top} style={styles.handleIn} />

      {/* Speaker */}
      <div style={styles.speaker}>
        {node.speaker ?? <em style={{ color: "#555" }}>narrator</em>}
      </div>

      {/* Text preview */}
      <div style={styles.text}>{truncate(node.text, 80)}</div>

      {/* Consequence badge */}
      {node.consequence && (
        <div style={styles.badge}>
          {node.consequence.action}
        </div>
      )}

      {/* Choice handles */}
      {node.choices.length === 0 ? (
        <div style={styles.terminal}>◼ terminal</div>
      ) : (
        <div style={styles.choices}>
          {node.choices.map((c, i) => (
            <div key={i} style={styles.choiceRow}>
              <span style={styles.choiceText}>{truncate(c.text, 28)}</span>
              <Handle
                type="source"
                position={Position.Bottom}
                id={`choice-${i}`}
                style={{
                  ...styles.handleOut,
                  left: `${((i + 0.5) / node.choices.length) * 100}%`,
                }}
              />
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

const styles = {
  card: {
    background: "#1e1e2e",
    border: "1px solid #333",
    borderRadius: 6,
    padding: "10px 14px 24px",
    minWidth: 220,
    maxWidth: 260,
    cursor: "pointer",
    position: "relative" as const,
    fontFamily: "system-ui, sans-serif",
  },
  cardSelected: {
    border: "1px solid #7a7af5",
    boxShadow: "0 0 0 2px #7a7af520",
  },
  handleIn: {
    background: "#7a7af5",
    width: 10,
    height: 10,
    border: "none",
    top: -5,
  },
  handleOut: {
    background: "#f5a07a",
    width: 10,
    height: 10,
    border: "none",
    bottom: -5,
    transform: "translateX(-50%)",
    position: "absolute" as const,
  },
  speaker: {
    fontSize: 11,
    fontWeight: 700,
    color: "#a0a0f5",
    marginBottom: 4,
    textTransform: "uppercase" as const,
    letterSpacing: "0.04em",
  },
  text: {
    fontSize: 12,
    color: "#ccc",
    lineHeight: 1.4,
    marginBottom: 6,
  },
  badge: {
    display: "inline-block",
    fontSize: 10,
    background: "#2a3020",
    color: "#8fa",
    border: "1px solid #3a4530",
    borderRadius: 3,
    padding: "1px 5px",
    marginBottom: 4,
  },
  terminal: {
    fontSize: 10,
    color: "#555",
    marginTop: 4,
  },
  choices: {
    display: "flex",
    flexDirection: "column" as const,
    gap: 2,
    marginTop: 4,
    position: "relative" as const,
  },
  choiceRow: {
    fontSize: 11,
    color: "#888",
    background: "#2a2a3a",
    padding: "2px 6px",
    borderRadius: 3,
  },
  choiceText: {
    display: "block",
  },
} as const;
