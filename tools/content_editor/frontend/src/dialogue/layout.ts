import type { DialogueJson, PositionMap } from "./types.js";

const H_GAP = 320;
const V_GAP = 200;

/** BFS from root nodes, returning positions for each node id. */
export function autoLayout(dialogue: DialogueJson): PositionMap {
  const nodes = dialogue.nodes;
  const ids = Object.keys(nodes);
  if (ids.length === 0) return {};

  // Find roots: nodes with no incoming edges, prefer "0" or "start"
  const hasIncoming = new Set<string>();
  for (const id of ids) {
    for (const choice of nodes[id].choices) {
      if (choice.next) hasIncoming.add(choice.next);
    }
  }
  const roots = ids.filter((id) => !hasIncoming.has(id));
  if (roots.length === 0) roots.push(ids[0]); // cycle fallback

  const positions: PositionMap = {};
  const visited = new Set<string>();
  const layers: string[][] = [];

  // BFS layer assignment
  let queue: string[] = [...roots];
  while (queue.length > 0) {
    const layer: string[] = [];
    const next: string[] = [];
    for (const id of queue) {
      if (visited.has(id)) continue;
      visited.add(id);
      layer.push(id);
      for (const choice of nodes[id].choices) {
        if (choice.next && !visited.has(choice.next)) next.push(choice.next);
      }
    }
    if (layer.length > 0) layers.push(layer);
    queue = next;
  }

  // Any unreachable nodes appended as a final layer
  const unreachable = ids.filter((id) => !visited.has(id));
  if (unreachable.length > 0) layers.push(unreachable);

  // Assign positions
  for (let y = 0; y < layers.length; y++) {
    const layer = layers[y];
    const totalWidth = (layer.length - 1) * H_GAP;
    for (let x = 0; x < layer.length; x++) {
      positions[layer[x]] = {
        x: x * H_GAP - totalWidth / 2,
        y: y * V_GAP,
      };
    }
  }

  return positions;
}
