/**
 * Dedicated builder for a PatronSaintData "lineage": its lineage_id plus the
 * three act-indexed tier blessings (Act 1/2/3).  Because a saint and all of its
 * tier BlessingData must share the same lineage_id, this panel can stamp the id
 * across the separate tier .tres files in one action — a cross-resource op the
 * generic per-field widgets can't do.
 */
import { useState } from "react";
import type { GameSchema, PropDescriptor } from "../types/schema.js";
import { FieldRenderer } from "./FieldRenderer.js";
import { api } from "../api.js";

const TIER_DIR = "res://resources/patron_saints/tiers/";
const ACT_LABELS = ["Act 1 — Initiate", "Act 2 — Adept", "Act 3 — Avatar"];

type Ref = { __ref: string };

interface Props {
  data: Record<string, unknown>;
  updateField: (name: string, value: unknown) => void;
  schema: GameSchema;
  onNavigate?: (path: string) => void;
}

export function LineageBuilder({ data, updateField, schema, onNavigate }: Props) {
  const [status, setStatus] = useState<string>("");
  const [busy, setBusy] = useState(false);

  const lineageId = (data.lineage_id as { __sn?: string } | null)?.__sn ?? "";
  const rawTiers = Array.isArray(data.tiers) ? (data.tiers as unknown[]) : [];
  // Always present exactly three slots; unfilled ones show as (none).
  const slots: unknown[] = [rawTiers[0] ?? null, rawTiers[1] ?? null, rawTiers[2] ?? null];

  function setLineageId(v: string) {
    updateField("lineage_id", { __sn: v });
  }

  function setTier(i: number, value: unknown) {
    const next = [...slots];
    next[i] = value;
    // Drop trailing empty slots so we never persist null tier entries.
    let end = next.length;
    while (end > 0 && (next[end - 1] == null)) end--;
    updateField("tiers", next.slice(0, end));
  }

  function tierPath(ref: unknown): string | null {
    return ref && typeof ref === "object" && "__ref" in (ref as object)
      ? (ref as Ref).__ref
      : null;
  }

  async function createTier(i: number) {
    if (!lineageId) {
      setStatus("Set a lineage id first.");
      return;
    }
    const path = `${TIER_DIR}${lineageId}_tier${i + 1}.tres`;
    setBusy(true);
    setStatus(`Creating ${path.split("/").pop()}…`);
    try {
      await api.newResource(path, "BlessingData");
      // Stamp lineage_id + a starter display name on the fresh blessing.
      const created = (await api.readResource(path)) as Record<string, unknown>;
      created.lineage_id = { __sn: lineageId };
      if (!created.display_name) {
        created.display_name = `${titleCase(lineageId)} — ${ACT_LABELS[i].split("— ")[1] ?? ""}`.trim();
      }
      await api.writeResource(path, created);
      setTier(i, { __ref: path });
      setStatus(`Created ${path.split("/").pop()}. Remember to Save the saint.`);
    } catch (e) {
      setStatus(`Create failed: ${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  async function applyLineageToTiers() {
    if (!lineageId) {
      setStatus("Set a lineage id first.");
      return;
    }
    const paths = slots.map(tierPath).filter((p): p is string => !!p);
    if (paths.length === 0) {
      setStatus("No tier blessings to stamp.");
      return;
    }
    setBusy(true);
    setStatus(`Stamping lineage id onto ${paths.length} tier(s)…`);
    try {
      for (const p of paths) {
        const tier = (await api.readResource(p)) as Record<string, unknown>;
        tier.lineage_id = { __sn: lineageId };
        await api.writeResource(p, tier);
      }
      setStatus(`Applied "${lineageId}" to ${paths.length} tier(s).`);
    } catch (e) {
      setStatus(`Apply failed: ${String(e)}`);
    } finally {
      setBusy(false);
    }
  }

  const tierProp: PropDescriptor = { name: "tier", type: "Resource", resource_type: "BlessingData" };

  return (
    <div style={styles.panel}>
      <div style={styles.title}>Lineage</div>

      <div style={styles.idRow}>
        <label style={styles.idLabel}>lineage_id</label>
        <input
          type="text"
          value={lineageId}
          onChange={(e) => setLineageId(e.target.value)}
          placeholder="e.g. ambush"
          style={styles.idInput}
        />
        <button style={styles.applyBtn} onClick={applyLineageToTiers} disabled={busy}>
          Apply id to all tiers
        </button>
      </div>

      {slots.map((ref, i) => {
        const path = tierPath(ref);
        return (
          <div key={i} style={styles.tierRow}>
            <span style={styles.act}>{ACT_LABELS[i]}</span>
            <div style={{ flex: 1, minWidth: 0 }}>
              <FieldRenderer
                prop={tierProp}
                value={ref}
                onChange={(v) => setTier(i, v)}
                schema={schema}
                onNavigate={onNavigate}
                dirOverride={TIER_DIR}
              />
            </div>
            {!path && (
              <button style={styles.createBtn} onClick={() => createTier(i)} disabled={busy}>
                + create tier
              </button>
            )}
          </div>
        );
      })}

      {status && <div style={styles.status}>{status}</div>}
    </div>
  );
}

function titleCase(s: string): string {
  return s.replace(/(^|[_\s])(\w)/g, (_, sep, c) => (sep ? " " : "") + c.toUpperCase()).trim();
}

const styles = {
  panel: {
    border: "1px solid #3a3a52",
    borderRadius: 6,
    background: "#181824",
    padding: "10px 12px",
    marginBottom: 12,
  },
  title: { color: "#bbe", fontSize: 13, fontWeight: 600, marginBottom: 8 },
  idRow: { display: "flex", alignItems: "center", gap: 8, marginBottom: 10 },
  idLabel: { color: "#999", fontSize: 12, fontFamily: "monospace", width: 80, flexShrink: 0 },
  idInput: {
    flex: 1,
    background: "#222",
    color: "#eee",
    border: "1px solid #444",
    borderRadius: 3,
    padding: "3px 6px",
    fontSize: 13,
    fontFamily: "monospace",
  },
  applyBtn: {
    padding: "4px 10px",
    background: "#2a3a5a",
    border: "1px solid #3a4a7a",
    color: "#bcd",
    cursor: "pointer",
    borderRadius: 3,
    fontSize: 12,
    flexShrink: 0,
  },
  tierRow: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    padding: "5px 0",
    borderTop: "1px solid #262636",
  },
  act: { color: "#889", fontSize: 12, width: 120, flexShrink: 0 },
  createBtn: {
    padding: "3px 8px",
    background: "#223322",
    border: "1px solid #345034",
    color: "#9c9",
    cursor: "pointer",
    borderRadius: 3,
    fontSize: 12,
    flexShrink: 0,
  },
  status: { color: "#9ab", fontSize: 11, marginTop: 8, fontStyle: "italic" as const },
} as const;
