/**
 * Read-only, sortable overview table.
 *
 * Unlike ResourceTable (schema-driven, inline-editing), this is a presentational
 * shell: callers supply their own column set and pre-loaded rows.  Every row is a
 * summary that links to a full editor via `onRowOpen`.  Used for the two-tier
 * event/dialogue views and the per-floor slot overview, where the meaningful
 * columns live outside the .tres schema.
 */
import {
  createColumnHelper,
  flexRender,
  getCoreRowModel,
  getSortedRowModel,
  useReactTable,
  type SortingState,
} from "@tanstack/react-table";
import { useState } from "react";

export interface SummaryRow {
  __path: string;
  [key: string]: unknown;
}

export interface SummaryColumn {
  id: string;
  header: string;
  size?: number;
  /** Value used for sorting (and default rendering when `cell` is omitted). */
  accessor: (row: SummaryRow) => unknown;
  /** Optional custom cell renderer. */
  cell?: (row: SummaryRow) => React.ReactNode;
}

interface Props {
  title: string;
  count: number;
  rows: SummaryRow[];
  columns: SummaryColumn[];
  loading: boolean;
  onRowOpen: (path: string) => void;
  /** Label for the first (file/name) column. Defaults to "file". */
  firstColLabel?: string;
  /** Renders the first-column button label. Defaults to the filename. */
  firstColLabelFor?: (row: SummaryRow) => string;
}

const columnHelper = createColumnHelper<SummaryRow>();

function defaultName(path: string): string {
  return path.split("/").pop()?.replace(/\.(tres|json)$/, "") ?? path;
}

export function SummaryTable({
  title,
  count,
  rows,
  columns,
  loading,
  onRowOpen,
  firstColLabel = "file",
  firstColLabelFor,
}: Props) {
  const [sorting, setSorting] = useState<SortingState>([]);

  const tableColumns = [
    columnHelper.accessor("__path", {
      id: "__path",
      header: firstColLabel,
      size: 180,
      cell: (info) => {
        const p = info.getValue();
        const row = info.row.original;
        const label = firstColLabelFor ? firstColLabelFor(row) : defaultName(p);
        return (
          <button style={cellBtnStyle} onClick={() => onRowOpen(p)} title={p}>
            {label}
          </button>
        );
      },
    }),
    ...columns.map((col) =>
      columnHelper.accessor((row) => col.accessor(row), {
        id: col.id,
        header: col.header,
        size: col.size ?? 100,
        cell: (info) => {
          const row = info.row.original;
          if (col.cell) return col.cell(row);
          const v = col.accessor(row);
          return <span style={cellTextStyle}>{v == null ? "—" : String(v)}</span>;
        },
      })
    ),
  ];

  const table = useReactTable({
    data: rows,
    columns: tableColumns,
    state: { sorting },
    onSortingChange: setSorting,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
  });

  return (
    <div style={styles.container}>
      <div style={styles.toolbar}>
        <span style={styles.cls}>{title}</span>
        <span style={styles.count}>{count} items</span>
      </div>

      {loading ? (
        <div style={styles.loading}>Loading…</div>
      ) : (
        <div style={styles.scroll}>
          <table style={styles.table}>
            <thead>
              {table.getHeaderGroups().map((hg) => (
                <tr key={hg.id}>
                  {hg.headers.map((h) => (
                    <th
                      key={h.id}
                      style={{ ...styles.th, width: h.getSize() }}
                      onClick={h.column.getToggleSortingHandler()}
                    >
                      {flexRender(h.column.columnDef.header, h.getContext())}
                      {h.column.getIsSorted() === "asc"
                        ? " ▲"
                        : h.column.getIsSorted() === "desc"
                        ? " ▼"
                        : ""}
                    </th>
                  ))}
                </tr>
              ))}
            </thead>
            <tbody>
              {table.getRowModel().rows.map((row) => (
                <tr key={row.id}>
                  {row.getVisibleCells().map((cell) => (
                    <td key={cell.id} style={styles.td}>
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

const cellBtnStyle: React.CSSProperties = {
  background: "none",
  border: "none",
  color: "#88aaff",
  cursor: "pointer",
  padding: "1px 4px",
  fontSize: 12,
  fontFamily: "monospace",
  textAlign: "left",
};

const cellTextStyle: React.CSSProperties = {
  fontSize: 12,
  fontFamily: "monospace",
  color: "#ccc",
};

const styles = {
  container: {
    flex: 1,
    display: "flex",
    flexDirection: "column" as const,
    overflow: "hidden",
    background: "#111",
  },
  toolbar: {
    display: "flex",
    alignItems: "center",
    gap: 12,
    padding: "8px 16px",
    borderBottom: "1px solid #333",
    background: "#161616",
  },
  cls: { fontSize: 14, fontWeight: 600, color: "#eee" },
  count: { fontSize: 12, color: "#666" },
  loading: { padding: 24, color: "#555" },
  scroll: { flex: 1, overflowX: "auto" as const, overflowY: "auto" as const },
  table: {
    borderCollapse: "collapse" as const,
    width: "100%",
    fontSize: 12,
  },
  th: {
    padding: "6px 8px",
    textAlign: "left" as const,
    color: "#aaa",
    background: "#1a1a1a",
    borderBottom: "1px solid #333",
    fontWeight: 500,
    cursor: "pointer",
    whiteSpace: "nowrap" as const,
    userSelect: "none" as const,
  },
  td: {
    padding: "2px 8px",
    borderBottom: "1px solid #1e1e1e",
    verticalAlign: "middle" as const,
  },
} as const;
