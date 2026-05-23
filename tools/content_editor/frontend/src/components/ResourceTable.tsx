/**
 * Spreadsheet view for a content type.
 * Cheap fields (numbers, strings, enum dropdowns) are inline-editable.
 * Complex fields (arrays, dictionaries, sub-resources) show a summary that
 * navigates to the form view on click.
 */
import { useEffect, useState, useCallback } from "react";
import {
  createColumnHelper,
  flexRender,
  getCoreRowModel,
  getSortedRowModel,
  useReactTable,
  type SortingState,
} from "@tanstack/react-table";
import type { GameSchema, PropDescriptor } from "../types/schema.js";
import { getAllProperties } from "../types/schema.js";
import { api } from "../api.js";
import { FieldRenderer } from "./FieldRenderer.js";

interface RowData {
  __path: string;
  [key: string]: unknown;
}

interface Props {
  cls: string;
  schema: GameSchema;
  onOpenForm: (path: string) => void;
}

const columnHelper = createColumnHelper<RowData>();

// Fields that are "cheap" enough for inline table editing
function isCheap(prop: PropDescriptor): boolean {
  return ["bool", "int", "float", "String", "enum"].includes(prop.type);
}

export function ResourceTable({ cls, schema, onOpenForm }: Props) {
  const [rows, setRows] = useState<RowData[]>([]);
  const [loading, setLoading] = useState(false);
  const [dirty, setDirty] = useState<Set<string>>(new Set());
  const [sorting, setSorting] = useState<SortingState>([]);

  const props = getAllProperties(cls, schema);
  const cheapProps = props.filter(isCheap);

  // Load all resources of this type
  useEffect(() => {
    setLoading(true);
    setRows([]);
    setDirty(new Set());

    api.listType(cls).then(async (paths) => {
      const loaded = await Promise.all(
        paths.map((p) =>
          api.readResource(p).then((d) => ({ ...(d as object), __path: p }))
        )
      );
      setRows(loaded as RowData[]);
      setLoading(false);
    });
  }, [cls]);

  const updateCell = useCallback((path: string, fieldName: string, value: unknown) => {
    setRows((prev) =>
      prev.map((r) => (r.__path === path ? { ...r, [fieldName]: value } : r))
    );
    setDirty((prev) => new Set([...prev, path]));
  }, []);

  const saveAll = useCallback(async () => {
    const toSave = rows.filter((r) => dirty.has(r.__path));
    await Promise.all(toSave.map((r) => api.writeResource(r.__path, r)));
    setDirty(new Set());
  }, [rows, dirty]);

  const columns = [
    columnHelper.accessor("__path", {
      id: "__path",
      header: "file",
      size: 160,
      cell: (info) => {
        const p = info.getValue();
        const name = p.split("/").pop()?.replace(".tres", "") ?? p;
        return (
          <button
            style={cellBtnStyle}
            onClick={() => onOpenForm(p)}
            title={p}
          >
            {name}
          </button>
        );
      },
    }),
    ...cheapProps.map((prop) =>
      columnHelper.accessor(prop.name as keyof RowData, {
        id: prop.name,
        header: prop.name,
        size: prop.type === "String" ? 200 : 100,
        cell: (info) => {
          const row = info.row.original;
          return (
            <FieldRenderer
              prop={prop}
              value={info.getValue()}
              onChange={(v) => updateCell(row.__path, prop.name, v)}
              schema={schema}
            />
          );
        },
      })
    ),
    // Complex props → summary cell linking to form
    ...props
      .filter((p) => !isCheap(p))
      .map((prop) =>
        columnHelper.accessor(prop.name as keyof RowData, {
          id: prop.name,
          header: prop.name,
          size: 120,
          cell: (info) => {
            const val = info.getValue();
            const row = info.row.original;
            const summary = summarize(val, prop);
            return (
              <button
                style={cellBtnStyle}
                onClick={() => onOpenForm(row.__path)}
                title={JSON.stringify(val, null, 2)}
              >
                {summary}
              </button>
            );
          },
        })
      ),
  ];

  const table = useReactTable({
    data: rows,
    columns,
    state: { sorting },
    onSortingChange: setSorting,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
  });

  return (
    <div style={styles.container}>
      <div style={styles.toolbar}>
        <span style={styles.cls}>{cls}</span>
        <span style={styles.count}>{rows.length} items</span>
        {dirty.size > 0 && (
          <button style={styles.saveBtn} onClick={saveAll}>
            Save {dirty.size} changed
          </button>
        )}
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
                <tr
                  key={row.id}
                  style={
                    dirty.has(row.original.__path) ? styles.dirtyRow : {}
                  }
                >
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

function summarize(val: unknown, prop: PropDescriptor): string {
  if (val == null) return "—";
  if (Array.isArray(val)) return `[${val.length}]`;
  if (typeof val === "object") {
    if ("__ref" in (val as object)) {
      const ref = (val as { __ref: string }).__ref;
      return ref.split("/").pop()?.replace(".tres", "") ?? "ref";
    }
    if ("_godot_meta" in (val as object)) return "[inline]";
    const keys = Object.keys(val).filter((k) => !k.startsWith("_"));
    return `{${keys.length}}`;
  }
  return String(val);
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
  saveBtn: {
    marginLeft: "auto",
    padding: "4px 12px",
    background: "#2a4a2a",
    border: "1px solid #3a6a3a",
    color: "#8f8",
    cursor: "pointer",
    borderRadius: 3,
    fontSize: 12,
  },
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
  dirtyRow: { background: "#1a1a10" },
} as const;
