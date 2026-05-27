import { useEffect, useState, useCallback } from "react";
import { api } from "../api.js";
import { CONTENT_TYPES, BUILDER_VIEWS } from "../types/schema.js";

interface Props {
  selectedType: string | null;
  onSelectType: (cls: string) => void;
  selectedPath: string | null;
  onSelectPath: (path: string) => void;
  onOpenGuide: (anchor: string) => void;
}

const TOC: Array<{ heading: string; items: Array<{ label: string; anchor: string }> }> = [
  {
    heading: "Part 1 — Tools",
    items: [
      { label: "Sidebar", anchor: "sidebar" },
      { label: "Form View", anchor: "form-view" },
      { label: "Table View", anchor: "table-view" },
      { label: "Where-Used Panel", anchor: "where-used" },
      { label: "Dialogue Editor", anchor: "dialogue-editor" },
      { label: "Event Editor", anchor: "event-editor" },
      { label: "Schema Refresh", anchor: "schema-refresh" },
    ],
  },
  {
    heading: "Part 2 — Resources",
    items: [
      { label: "WeaponData", anchor: "weapondata" },
      { label: "EquipmentData", anchor: "equipmentdata" },
      { label: "AttackData", anchor: "attackdata" },
      { label: "Effects", anchor: "effects" },
      { label: "ConditionalModifier", anchor: "conditionalmodifier" },
      { label: "ProcDef", anchor: "procdef" },
      { label: "StatusData", anchor: "statusdata" },
      { label: "ConsumableData", anchor: "consumabledata" },
      { label: "PlayerClassData", anchor: "playerclassdata" },
      { label: "ShopData", anchor: "shopdata" },
      { label: "BlessingData", anchor: "blessingdata" },
      { label: "SpellData", anchor: "spelldata" },
      { label: "TomeData", anchor: "tomedata" },
      { label: "DialogueData", anchor: "dialoguedata" },
      { label: "Event Wrappers", anchor: "event-wrapper-types" },
      { label: "DungeonFloorData", anchor: "dungeonfloordata" },
      { label: "FloorSlot", anchor: "floorslot" },
      { label: "WeightedEntry", anchor: "weightedentry" },
    ],
  },
  {
    heading: "Part 3 — Workflows",
    items: [
      { label: "Add a weapon", anchor: "workflow-add-weapon" },
      { label: "Add dialogue branch", anchor: "workflow-add-dialogue-branch" },
      { label: "Bulk-tune damage", anchor: "workflow-bulk-tune" },
      { label: "Track references", anchor: "workflow-where-used" },
    ],
  },
];

export function Sidebar({ selectedType, onSelectType, selectedPath, onSelectPath, onOpenGuide }: Props) {
  const [files, setFiles] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);
  const [guideOpen, setGuideOpen] = useState(false);
  const [hoveredAnchor, setHoveredAnchor] = useState<string | null>(null);

  const refreshFiles = useCallback((cls: string) => {
    setLoading(true);
    api.listType(cls)
      .then(setFiles)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (!selectedType) return;
    if (BUILDER_VIEWS.has(selectedType)) return;
    refreshFiles(selectedType);
  }, [selectedType, refreshFiles]);

  const handleNew = useCallback(async (cls: string, dir: string) => {
    // Effects section offers multiple concrete types
    let createCls = cls;
    if (cls === "DamageEffect") {
      const pick = window.prompt(
        "Effect type:\n1 DamageEffect\n2 HealEffect\n3 BuffEffect\n4 StatusEffect\n\nEnter number:"
      );
      const map: Record<string, string> = {
        "1": "DamageEffect", "2": "HealEffect", "3": "BuffEffect", "4": "StatusEffect",
      };
      createCls = map[pick?.trim() ?? ""] ?? "DamageEffect";
    }

    const name = window.prompt(`New ${createCls} filename (no extension):`);
    if (!name) return;
    const path = `${dir}${name.replace(/\.tres$/, "")}.tres`;
    try {
      await api.newResource(path, createCls);
      if (selectedType === cls) refreshFiles(cls);
      onSelectPath(path);
    } catch (e) {
      window.alert(`Failed to create: ${e}`);
    }
  }, [selectedType, refreshFiles, onSelectPath]);

  return (
    <aside style={styles.aside}>
      <div style={styles.typeSection}>
        {CONTENT_TYPES.map(({ label, cls, dir }) => {
          const isBuilder = BUILDER_VIEWS.has(cls);
          return (
            <div
              key={cls}
              style={{
                ...styles.typeRow,
                ...(selectedType === cls ? styles.typeRowActive : {}),
              }}
            >
              <button
                style={styles.typeButton}
                onClick={() => { onSelectType(cls); onSelectPath(""); }}
              >
                {label}
              </button>
              {!isBuilder && (
                <button
                  style={styles.newBtn}
                  title={`New ${cls}`}
                  onClick={(e) => { e.stopPropagation(); handleNew(cls, dir); }}
                >
                  +
                </button>
              )}
            </div>
          );
        })}
      </div>

      {/* User Guide section */}
      <div style={styles.guideSection}>
        <button
          style={styles.guideToggle}
          onClick={() => setGuideOpen((v) => !v)}
        >
          <span style={styles.guideCaret}>{guideOpen ? "▾" : "▸"}</span>
          User Guide
        </button>
        {guideOpen && (
          <div style={styles.guideToc}>
            {TOC.map((group) => (
              <div key={group.heading}>
                <div style={styles.tocHeading}>{group.heading}</div>
                {group.items.map((item) => (
                  <button
                    key={item.anchor}
                    style={{
                      ...styles.tocItem,
                      ...(hoveredAnchor === item.anchor ? styles.tocItemHover : {}),
                    }}
                    onMouseEnter={() => setHoveredAnchor(item.anchor)}
                    onMouseLeave={() => setHoveredAnchor(null)}
                    onClick={() => onOpenGuide(item.anchor)}
                  >
                    {item.label}
                  </button>
                ))}
              </div>
            ))}
          </div>
        )}
      </div>

      {!BUILDER_VIEWS.has(selectedType ?? "") && (
        <div style={styles.fileList}>
          {loading && <div style={styles.hint}>Loading…</div>}
          {!loading && files.length === 0 && selectedType && (
            <div style={styles.hint}>No files found</div>
          )}
          {files.map((p) => {
            const name = p.split("/").pop() ?? p;
            return (
              <button
                key={p}
                title={p}
                style={{
                  ...styles.fileButton,
                  ...(selectedPath === p ? styles.fileButtonActive : {}),
                }}
                onClick={() => onSelectPath(p)}
              >
                {name.replace(".tres", "")}
              </button>
            );
          })}
        </div>
      )}
    </aside>
  );
}

const styles = {
  aside: {
    width: 220,
    minWidth: 220,
    display: "flex",
    flexDirection: "column" as const,
    borderRight: "1px solid #333",
    background: "#1a1a1a",
    overflowY: "auto" as const,
  },
  typeSection: {
    display: "flex",
    flexDirection: "column" as const,
    borderBottom: "1px solid #333",
  },
  typeRow: {
    display: "flex",
    alignItems: "center",
  },
  typeRowActive: {
    background: "#2a2a4a",
  },
  typeButton: {
    flex: 1,
    padding: "10px 14px",
    background: "none",
    border: "none",
    color: "#ccc",
    cursor: "pointer",
    textAlign: "left" as const,
    fontSize: 13,
  },
  newBtn: {
    padding: "0 10px",
    background: "none",
    border: "none",
    color: "#666",
    cursor: "pointer",
    fontSize: 18,
    lineHeight: 1,
    flexShrink: 0,
    height: "100%",
  },
  fileList: {
    flex: 1,
    overflowY: "auto" as const,
    padding: "4px 0",
  },
  fileButton: {
    display: "block",
    width: "100%",
    padding: "6px 14px",
    background: "none",
    border: "none",
    color: "#aaa",
    cursor: "pointer",
    textAlign: "left" as const,
    fontSize: 12,
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap" as const,
  },
  fileButtonActive: {
    background: "#2a3a2a",
    color: "#eee",
  },
  hint: { color: "#555", fontSize: 12, padding: "8px 14px" },
  guideSection: {
    borderTop: "1px solid #222233",
    borderBottom: "1px solid #222233",
    background: "#13131e",
    flexShrink: 0,
  },
  guideToggle: {
    display: "flex",
    alignItems: "center",
    gap: 7,
    width: "100%",
    padding: "9px 14px",
    background: "none",
    border: "none",
    color: "#7a8cbb",
    cursor: "pointer",
    textAlign: "left" as const,
    fontSize: 13,
    fontWeight: 500,
  },
  guideCaret: {
    fontSize: 10,
    color: "#4455aa",
    flexShrink: 0,
  },
  guideToc: {
    maxHeight: 280,
    overflowY: "auto" as const,
    paddingBottom: 6,
  },
  tocHeading: {
    padding: "6px 14px 3px",
    fontSize: 10,
    color: "#3d4d88",
    textTransform: "uppercase" as const,
    letterSpacing: "0.5px",
    fontWeight: 700,
  },
  tocItem: {
    display: "block",
    width: "100%",
    padding: "3px 14px 3px 24px",
    background: "none",
    border: "none",
    color: "#6677aa",
    cursor: "pointer",
    textAlign: "left" as const,
    fontSize: 12,
  },
  tocItemHover: {
    background: "#1a1a2e",
    color: "#99aadd",
  },
} as const;
