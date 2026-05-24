import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ReactFlow,
  Background,
  Controls,
  applyNodeChanges,
  applyEdgeChanges,
  addEdge,
  type Node,
  type Edge,
  type NodeChange,
  type EdgeChange,
  type Connection,
} from "@xyflow/react";
import "@xyflow/react/dist/style.css";
import { api } from "../api.js";
import { autoLayout } from "../dialogue/layout.js";
import type { DialogueJson, DialogueNode, PositionMap } from "../dialogue/types.js";
import { DialogueNodeCard } from "./DialogueNodeCard.js";

const nodeTypes = { dialogue: DialogueNodeCard };

const CONSEQUENCE_ACTIONS = ["give_item", "give_gold", "set_flag", "trigger_event"];

interface Props {
  resPath: string; // .tres path — used to read/write tres & dialogue_path
}

export function DialogueEditor({ resPath }: Props) {
  const [tresData, setTresData] = useState<Record<string, unknown> | null>(null);
  const [dialogue, setDialogue] = useState<DialogueJson | null>(null);
  const [nodes, setNodes] = useState<Node[]>([]);
  const [edges, setEdges] = useState<Edge[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [status, setStatus] = useState("");
  const [dirty, setDirty] = useState(false);
  const reactFlowInstance = useRef<{ fitView: () => void } | null>(null);

  // ----- Load -----
  useEffect(() => {
    setTresData(null);
    setDialogue(null);
    setNodes([]);
    setEdges([]);
    setSelectedId(null);
    setDirty(false);
    setStatus("");

    api.readResource(resPath).then(async (tres) => {
      const t = tres as Record<string, unknown>;
      setTresData(t);

      let jsonPath = t.dialogue_path as string | undefined;

      // New resource: auto-initialize a matching JSON file
      if (!jsonPath) {
        jsonPath = resPath.replace(/\.tres$/, ".json");
        const name = jsonPath.split("/").pop()?.replace(".json", "") ?? "dialogue";
        const blank: DialogueJson = {
          name,
          nodes: { "0": { speaker: null, text: "...", consequence: null, choices: [] } },
        };
        try {
          await api.writeDialogue(jsonPath, blank);
          await api.writeResource(resPath, { ...t, dialogue_path: jsonPath });
          setTresData({ ...t, dialogue_path: jsonPath });
          setDialogue(blank);
          const [rfNodes, rfEdges] = buildFlow(blank, {});
          setNodes(rfNodes);
          setEdges(rfEdges);
          setTimeout(() => reactFlowInstance.current?.fitView(), 50);
        } catch (e) {
          setStatus(`Failed to initialize: ${e}`);
        }
        return;
      }

      api.readDialogue(jsonPath).then((dlg) => {
        const d = dlg as DialogueJson;
        setDialogue(d);
        const savedPositions: PositionMap = parsePositions(t.node_positions_json as string);
        const [rfNodes, rfEdges] = buildFlow(d, savedPositions);
        setNodes(rfNodes);
        setEdges(rfEdges);
        setTimeout(() => reactFlowInstance.current?.fitView(), 50);
      }).catch((e) => setStatus(`Error loading JSON: ${e}`));
    }).catch((e) => setStatus(`Error loading .tres: ${e}`));
  }, [resPath]);

  // ----- Helpers -----
  function parsePositions(json: string): PositionMap {
    if (!json) return {};
    try { return JSON.parse(json) as PositionMap; } catch { return {}; }
  }

  function buildFlow(dlg: DialogueJson, positions: PositionMap): [Node[], Edge[]] {
    const autoPos = autoLayout(dlg);
    const rfNodes: Node[] = Object.entries(dlg.nodes).map(([id, node]) => ({
      id,
      type: "dialogue",
      position: positions[id] ?? autoPos[id] ?? { x: 0, y: 0 },
      data: { node, nodeId: id, selected: false },
    }));
    const rfEdges: Edge[] = [];
    for (const [id, node] of Object.entries(dlg.nodes)) {
      node.choices.forEach((c, i) => {
        if (c.next) {
          rfEdges.push({
            id: `${id}-choice-${i}`,
            source: id,
            sourceHandle: `choice-${i}`,
            target: c.next,
            style: { stroke: "#f5a07a", strokeWidth: 1.5 },
            animated: false,
          });
        }
      });
    }
    return [rfNodes, rfEdges];
  }

  // Rebuild flow from current dialogue + current node positions
  function rebuildFromDialogue(dlg: DialogueJson, currentNodes: Node[]) {
    const positions: PositionMap = {};
    for (const n of currentNodes) positions[n.id] = n.position;
    const [rfNodes, rfEdges] = buildFlow(dlg, positions);
    setNodes(rfNodes);
    setEdges(rfEdges);
  }

  // ----- React Flow handlers -----
  const onNodesChange = useCallback((changes: NodeChange[]) => {
    setNodes((ns) => applyNodeChanges(changes, ns));
    setDirty(true);
  }, []);

  const onEdgesChange = useCallback((changes: EdgeChange[]) => {
    setEdges((es) => {
      const updated = applyEdgeChanges(changes, es);
      setDirty(true);
      return updated;
    });
  }, []);

  const onConnect = useCallback((conn: Connection) => {
    if (!conn.sourceHandle) return;
    // Each choice handle allows only one outgoing edge — remove existing if present
    setEdges((es) => {
      const pruned = es.filter(
        (e) => !(e.source === conn.source && e.sourceHandle === conn.sourceHandle)
      );
      return addEdge({ ...conn, style: { stroke: "#f5a07a", strokeWidth: 1.5 } }, pruned);
    });
    setDirty(true);
  }, []);

  // ----- Selected node mutation -----
  const selectedNode: DialogueNode | null = useMemo(() => {
    if (!selectedId || !dialogue) return null;
    return dialogue.nodes[selectedId] ?? null;
  }, [selectedId, dialogue]);

  function updateSelectedNode(patch: Partial<DialogueNode>) {
    if (!selectedId || !dialogue) return;
    const updated: DialogueJson = {
      ...dialogue,
      nodes: {
        ...dialogue.nodes,
        [selectedId]: { ...dialogue.nodes[selectedId], ...patch },
      },
    };
    setDialogue(updated);
    rebuildFromDialogue(updated, nodes);
    setDirty(true);
  }

  function updateChoiceText(i: number, text: string) {
    if (!selectedNode) return;
    const choices = selectedNode.choices.map((c, idx) => idx === i ? { ...c, text } : c);
    updateSelectedNode({ choices });
  }

  function addChoice() {
    if (!selectedNode) return;
    updateSelectedNode({ choices: [...selectedNode.choices, { text: "...", next: "" }] });
  }

  function removeChoice(i: number) {
    if (!selectedNode) return;
    const choices = selectedNode.choices.filter((_, idx) => idx !== i);
    updateSelectedNode({ choices });
    // Remove any edge from this handle
    setEdges((es) => es.filter((e) => !(e.source === selectedId && e.sourceHandle === `choice-${i}`)));
  }

  // ----- Add / delete nodes -----
  function addNode() {
    if (!dialogue) return;
    const existingIds = Object.keys(dialogue.nodes).map(Number).filter((n) => !isNaN(n));
    const nextId = String((existingIds.length > 0 ? Math.max(...existingIds) : -1) + 1);
    const newNode: DialogueNode = { speaker: null, text: "New node", consequence: null, choices: [] };
    const updated: DialogueJson = { ...dialogue, nodes: { ...dialogue.nodes, [nextId]: newNode } };
    setDialogue(updated);
    const center = { x: 0, y: (Object.keys(dialogue.nodes).length) * 200 };
    setNodes((ns) => [...ns, {
      id: nextId,
      type: "dialogue",
      position: center,
      data: { node: newNode, nodeId: nextId, selected: false },
    }]);
    setSelectedId(nextId);
    setDirty(true);
  }

  function deleteNode(id: string) {
    if (!dialogue) return;
    const referrers = Object.entries(dialogue.nodes).filter(([nid, n]) =>
      nid !== id && n.choices.some((c) => c.next === id)
    ).map(([nid]) => nid);
    if (referrers.length > 0 && !confirm(`Node "${id}" is referenced by: ${referrers.join(", ")}. Delete anyway?`)) return;
    const updated: DialogueJson = { ...dialogue };
    delete updated.nodes[id];
    setDialogue(updated);
    setNodes((ns) => ns.filter((n) => n.id !== id));
    setEdges((es) => es.filter((e) => e.source !== id && e.target !== id));
    if (selectedId === id) setSelectedId(null);
    setDirty(true);
  }

  // ----- Save -----
  async function save() {
    if (!dialogue || !tresData) return;
    setStatus("Saving…");

    // Build the JSON with edges as the source of truth for choice.next
    const edgesBySource: Record<string, Record<string, string>> = {};
    for (const e of edges) {
      if (!e.sourceHandle) continue;
      if (!edgesBySource[e.source]) edgesBySource[e.source] = {};
      const idx = parseInt(e.sourceHandle.replace("choice-", ""), 10);
      edgesBySource[e.source][idx] = e.target;
    }
    const finalNodes: DialogueJson["nodes"] = {};
    for (const [id, node] of Object.entries(dialogue.nodes)) {
      const choices = node.choices.map((c, i) => ({
        ...c,
        next: edgesBySource[id]?.[i] ?? "",
      }));
      finalNodes[id] = { ...node, choices };
    }
    const finalDialogue: DialogueJson = { name: tresData.display_name as string || dialogue.name, nodes: finalNodes };

    // Positions from current node positions
    const positions: PositionMap = {};
    for (const n of nodes) positions[n.id] = n.position;

    const jsonPath = tresData.dialogue_path as string;
    try {
      await api.writeDialogue(jsonPath, finalDialogue);
      await api.writeResource(resPath, {
        ...tresData,
        node_positions_json: JSON.stringify(positions),
      });
      setDirty(false);
      setStatus("Saved.");
      setTimeout(() => setStatus(""), 2000);
    } catch (e) {
      setStatus(`Save failed: ${e}`);
    }
  }

  // Sync node data (text/fields and selection highlight) when dialogue or selection changes
  useEffect(() => {
    if (!dialogue) return;
    setNodes((ns) =>
      ns.map((n) => ({
        ...n,
        data: {
          ...n.data,
          node: dialogue.nodes[n.id] ?? n.data.node,
          selected: n.id === selectedId,
        },
      }))
    );
  }, [dialogue, selectedId]);

  if (!tresData) return <div style={s.loading}>Loading…</div>;

  return (
    <div style={s.root}>
      {/* Toolbar */}
      <div style={s.toolbar}>
        <span style={s.title}>{(tresData.display_name as string) || resPath.split("/").pop()}</span>
        <button style={s.btn} onClick={addNode}>+ Node</button>
        {selectedId && (
          <button style={{ ...s.btn, ...s.btnDanger }} onClick={() => deleteNode(selectedId)}>
            Delete "{selectedId}"
          </button>
        )}
        <button
          style={{ ...s.btn, ...(dirty ? s.btnPrimary : {}) }}
          onClick={save}
          disabled={!dirty}
        >
          {dirty ? "Save*" : "Saved"}
        </button>
        {status && <span style={s.status}>{status}</span>}
      </div>

      <div style={s.canvas}>
        {/* Graph */}
        <div style={s.flow}>
          <ReactFlow
            nodes={nodes}
            edges={edges}
            onNodesChange={onNodesChange}
            onEdgesChange={onEdgesChange}
            onConnect={onConnect}
            onNodeClick={(_, node) => setSelectedId(node.id)}
            onPaneClick={() => setSelectedId(null)}
            nodeTypes={nodeTypes}
            onInit={(inst) => { reactFlowInstance.current = inst as typeof reactFlowInstance.current; }}
            fitView
            deleteKeyCode="Delete"
            colorMode="dark"
          >
            <Background color="#222" gap={24} />
            <Controls />
          </ReactFlow>
        </div>

        {/* Side panel */}
        <div style={s.panel}>
          {selectedNode && selectedId ? (
            <NodePanel
              id={selectedId}
              node={selectedNode}
              onChange={updateSelectedNode}
              onChoiceText={updateChoiceText}
              onAddChoice={addChoice}
              onRemoveChoice={removeChoice}
            />
          ) : (
            <div style={s.noSelection}>Click a node to edit it.</div>
          )}
        </div>
      </div>
    </div>
  );
}

// ----- Node panel -----

interface NodePanelProps {
  id: string;
  node: DialogueNode;
  onChange: (patch: Partial<DialogueNode>) => void;
  onChoiceText: (i: number, text: string) => void;
  onAddChoice: () => void;
  onRemoveChoice: (i: number) => void;
}

function NodePanel({ id, node, onChange, onChoiceText, onAddChoice, onRemoveChoice }: NodePanelProps) {
  return (
    <div style={p.root}>
      <div style={p.id}>Node <code>{id}</code></div>

      <label style={p.label}>Speaker</label>
      <input
        style={p.input}
        placeholder="(narrator)"
        value={node.speaker ?? ""}
        onChange={(e) => onChange({ speaker: e.target.value || null })}
      />

      <label style={p.label}>Text</label>
      <textarea
        style={p.textarea}
        rows={4}
        value={node.text}
        onChange={(e) => onChange({ text: e.target.value })}
      />

      <label style={p.label}>Consequence</label>
      <div style={p.row}>
        <select
          style={p.select}
          value={node.consequence?.action ?? ""}
          onChange={(e) => {
            const action = e.target.value;
            if (!action) onChange({ consequence: null });
            else onChange({ consequence: { action, value: node.consequence?.value ?? "" } });
          }}
        >
          <option value="">(none)</option>
          {CONSEQUENCE_ACTIONS.map((a) => <option key={a} value={a}>{a}</option>)}
        </select>
        {node.consequence && (
          <input
            style={{ ...p.input, flex: 1, marginTop: 0 }}
            placeholder="value"
            value={node.consequence.value}
            onChange={(e) => onChange({ consequence: { ...node.consequence!, value: e.target.value } })}
          />
        )}
      </div>

      <label style={p.label}>Rewards</label>
      <div style={p.row}>
        <input
          style={{ ...p.input, flex: 1, marginTop: 0 }}
          type="number"
          placeholder="XP"
          value={node.rewards?.experience ?? ""}
          onChange={(e) => onChange({
            rewards: { experience: parseInt(e.target.value) || 0, gold: node.rewards?.gold ?? 0 },
          })}
        />
        <input
          style={{ ...p.input, flex: 1, marginTop: 0 }}
          type="number"
          placeholder="Gold"
          value={node.rewards?.gold ?? ""}
          onChange={(e) => onChange({
            rewards: { experience: node.rewards?.experience ?? 0, gold: parseInt(e.target.value) || 0 },
          })}
        />
      </div>

      <div style={p.choiceHeader}>
        <label style={p.label}>Choices</label>
        <button style={p.addBtn} onClick={onAddChoice}>+ Add</button>
      </div>
      {node.choices.map((c, i) => (
        <div key={i} style={p.choiceRow}>
          <span style={p.choiceNum}>{i}</span>
          <input
            style={{ ...p.input, flex: 1, marginTop: 0 }}
            value={c.text}
            onChange={(e) => onChoiceText(i, e.target.value)}
          />
          <button style={p.delBtn} onClick={() => onRemoveChoice(i)}>×</button>
        </div>
      ))}
      {node.choices.length === 0 && <div style={p.terminal}>Terminal node — no choices.</div>}
    </div>
  );
}

const s = {
  root: { display: "flex", flexDirection: "column" as const, height: "100%", overflow: "hidden" },
  toolbar: {
    display: "flex", gap: 6, padding: "6px 12px",
    borderBottom: "1px solid #2a2a2a", background: "#161616",
    alignItems: "center", flexShrink: 0,
  },
  title: { fontSize: 13, color: "#ccc", marginRight: 8 },
  btn: {
    padding: "4px 10px", background: "none", border: "1px solid #333",
    color: "#888", cursor: "pointer", borderRadius: 3, fontSize: 12,
  },
  btnPrimary: { background: "#2a3a5a", color: "#9af", borderColor: "#446" },
  btnDanger: { color: "#f88", borderColor: "#533" },
  status: { fontSize: 12, color: "#8a8", marginLeft: 8 },
  canvas: { display: "flex", flex: 1, overflow: "hidden" },
  flow: { flex: 1, position: "relative" as const },
  panel: {
    width: 280, flexShrink: 0, borderLeft: "1px solid #222",
    overflowY: "auto" as const, background: "#141420",
  },
  noSelection: { padding: 16, color: "#444", fontSize: 13 },
  loading: { padding: 24, color: "#555" },
} as const;

const p = {
  root: { padding: 14, display: "flex", flexDirection: "column" as const, gap: 4 },
  id: { fontSize: 11, color: "#555", marginBottom: 8 },
  label: { fontSize: 11, color: "#888", marginTop: 8, display: "block" as const },
  input: {
    marginTop: 2, padding: "4px 8px", background: "#1e1e2e",
    border: "1px solid #333", color: "#eee", borderRadius: 3,
    fontSize: 12, width: "100%", boxSizing: "border-box" as const,
  },
  textarea: {
    marginTop: 2, padding: "4px 8px", background: "#1e1e2e",
    border: "1px solid #333", color: "#eee", borderRadius: 3,
    fontSize: 12, width: "100%", resize: "vertical" as const,
    boxSizing: "border-box" as const, fontFamily: "inherit",
  },
  select: {
    padding: "4px 8px", background: "#1e1e2e", border: "1px solid #333",
    color: "#eee", borderRadius: 3, fontSize: 12,
  },
  row: { display: "flex", gap: 6, alignItems: "center", marginTop: 2 },
  choiceHeader: { display: "flex", alignItems: "center", justifyContent: "space-between", marginTop: 8 },
  addBtn: {
    padding: "2px 8px", background: "none", border: "1px solid #334",
    color: "#77a", cursor: "pointer", borderRadius: 3, fontSize: 11,
  },
  choiceRow: { display: "flex", alignItems: "center", gap: 4, marginTop: 2 },
  choiceNum: { fontSize: 10, color: "#555", width: 14, textAlign: "center" as const },
  delBtn: {
    padding: "0 6px", background: "none", border: "1px solid #422",
    color: "#c66", cursor: "pointer", borderRadius: 3, fontSize: 13,
    lineHeight: "20px",
  },
  terminal: { fontSize: 11, color: "#444", marginTop: 4 },
} as const;
