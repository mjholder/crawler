/**
 * Overview table for dialogues.
 *
 * Like events, dialogues are two-tier: a .tres wrapper (dialogue_path) points to a
 * JSON sidecar of the form { name, nodes }.  We fan out readResource + readDialogue
 * per file and summarise.  Read-only — clicking a row opens the graph DialogueEditor.
 */
import { useEffect, useState } from "react";
import { api } from "../api.js";
import type { DialogueJson } from "../dialogue/types.js";
import { SummaryTable, type SummaryColumn, type SummaryRow } from "./SummaryTable.js";

interface Props {
  onOpenForm: (path: string) => void;
}

interface DialogueRow extends SummaryRow {
  json: DialogueJson | null;
}

function dlg(row: SummaryRow): DialogueJson | null {
  return (row as DialogueRow).json;
}

const columns: SummaryColumn[] = [
  {
    id: "name",
    header: "name",
    size: 200,
    accessor: (r) => dlg(r)?.name ?? null,
  },
  {
    id: "nodes",
    header: "nodes",
    accessor: (r) => {
      const nodes = dlg(r)?.nodes;
      return nodes ? Object.keys(nodes).length : null;
    },
  },
  {
    id: "start",
    header: "start",
    size: 320,
    accessor: (r) => {
      const text = dlg(r)?.nodes?.["0"]?.text ?? "";
      return text.length > 60 ? text.slice(0, 60) + "…" : text || null;
    },
  },
];

export function DialogueTable({ onOpenForm }: Props) {
  const [rows, setRows] = useState<DialogueRow[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setRows([]);

    api.listType("DialogueData").then(async (paths) => {
      const loaded = await Promise.all(
        paths.map(async (p) => {
          const tres = (await api.readResource(p)) as Record<string, unknown>;
          const jsonPath = (tres.dialogue_path as string) ?? "";
          let data: DialogueJson | null = null;
          if (jsonPath) {
            data = (await api.readDialogue(jsonPath).catch(() => null)) as DialogueJson | null;
          }
          return { __path: p, json: data } as DialogueRow;
        })
      );
      if (!cancelled) {
        setRows(loaded);
        setLoading(false);
      }
    });

    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <SummaryTable
      title="DialogueData"
      count={rows.length}
      rows={rows}
      columns={columns}
      loading={loading}
      onRowOpen={onOpenForm}
    />
  );
}
