/**
 * Overview table for a single event class.
 *
 * Events are two-tier: a thin .tres wrapper (display_name + event_path) points to
 * a JSON sidecar holding the real content.  We fan out one readResource + one
 * readEvent per file (mirrors EventEditor's load) and derive per-type columns from
 * the JSON.  Read-only — clicking a row opens the full EventEditor.
 */
import { useEffect, useState } from "react";
import { api } from "../../api.js";
import { SummaryTable, type SummaryColumn, type SummaryRow } from "../SummaryTable.js";

interface Props {
  cls: string;
  onOpenForm: (path: string) => void;
}

interface EventRow extends SummaryRow {
  display_name: string;
  json: Record<string, unknown> | null;
}

function num(v: unknown): number | null {
  return typeof v === "number" ? v : null;
}

function str(v: unknown): string | null {
  return typeof v === "string" && v.length > 0 ? v : null;
}

function json(row: SummaryRow): Record<string, unknown> {
  return ((row as EventRow).json ?? {}) as Record<string, unknown>;
}

function displayName(row: SummaryRow): string | null {
  return str((row as EventRow).display_name);
}

function waveCount(row: SummaryRow): number | null {
  const waves = json(row).waves;
  return Array.isArray(waves) ? waves.length : null;
}

function enemyCount(row: SummaryRow): number | null {
  const waves = json(row).waves;
  if (!Array.isArray(waves)) return null;
  let total = 0;
  for (const w of waves) {
    const enemies = (w as Record<string, unknown>)?.enemies;
    if (Array.isArray(enemies)) {
      for (const e of enemies) total += num((e as Record<string, unknown>)?.count) ?? 0;
    }
  }
  return total;
}

function reward(row: SummaryRow, bag: string, key: string): number | null {
  const r = json(row)[bag] as Record<string, unknown> | undefined;
  return r ? num(r[key]) : null;
}

function basename(v: unknown): string | null {
  const s = str(v);
  return s ? (s.split("/").pop()?.replace(/\.tres$/, "") ?? s) : null;
}

const displayCol: SummaryColumn = {
  id: "display_name",
  header: "display_name",
  size: 200,
  accessor: displayName,
};

function columnsFor(cls: string): SummaryColumn[] {
  switch (cls) {
    case "CombatEventData":
    case "BossEventData": {
      const cols: SummaryColumn[] = [
        displayCol,
        { id: "waves", header: "waves", accessor: waveCount },
        { id: "enemies", header: "enemies", accessor: enemyCount },
        { id: "xp", header: "xp", accessor: (r) => reward(r, "rewards", "experience") },
        { id: "gold", header: "gold", accessor: (r) => reward(r, "rewards", "gold") },
      ];
      if (cls === "BossEventData") {
        cols.push({
          id: "triggers",
          header: "triggers",
          accessor: (r) => {
            const t = json(r).dialogue_triggers as Record<string, unknown> | undefined;
            return t ? Object.values(t).filter((v) => str(v)).length : null;
          },
        });
      }
      return cols;
    }
    case "SkillCheckEventData":
      return [
        displayCol,
        { id: "label", header: "label", size: 200, accessor: (r) => str(json(r).label) },
        { id: "stat", header: "stat", accessor: (r) => str(json(r).stat) },
        {
          id: "threshold",
          header: "threshold",
          size: 180,
          accessor: (r) => str(json(r).threshold_expression),
        },
        { id: "xp", header: "xp", accessor: (r) => reward(r, "rewards_on_success", "experience") },
        { id: "gold", header: "gold", accessor: (r) => reward(r, "rewards_on_success", "gold") },
      ];
    case "RestEventData":
      return [
        displayCol,
        {
          id: "heal",
          header: "heal_expression",
          size: 240,
          accessor: (r) => str(json(r).heal_expression),
        },
      ];
    case "DialogueEventData":
      return [
        displayCol,
        {
          id: "dialogue",
          header: "dialogue",
          size: 200,
          accessor: (r) => basename(json(r).dialogue),
        },
      ];
    default:
      return [displayCol];
  }
}

export function EventTable({ cls, onOpenForm }: Props) {
  const [rows, setRows] = useState<EventRow[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setRows([]);

    api.listType(cls).then(async (paths) => {
      const loaded = await Promise.all(
        paths.map(async (p) => {
          const tres = (await api.readResource(p)) as Record<string, unknown>;
          const display_name = (tres.display_name as string) ?? "";
          const eventPath = (tres.event_path as string) ?? "";
          let data: Record<string, unknown> | null = null;
          if (eventPath) {
            data = (await api.readEvent(eventPath).catch(() => null)) as
              | Record<string, unknown>
              | null;
          }
          return { __path: p, display_name, json: data } as EventRow;
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
  }, [cls]);

  return (
    <SummaryTable
      title={cls}
      count={rows.length}
      rows={rows}
      columns={columnsFor(cls)}
      loading={loading}
      onRowOpen={onOpenForm}
    />
  );
}
