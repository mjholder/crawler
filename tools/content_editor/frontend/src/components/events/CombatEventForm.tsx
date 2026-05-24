import { PathPicker } from "./PathPicker.js";

interface Enemy { scene: string; count: number }
interface Wave { enemies: Enemy[]; on_clear_trigger?: string }
interface Rewards { experience?: number; gold?: number }
interface DialogueTriggers { on_start?: string; on_mid?: string; on_victory?: string }

interface Props {
  json: Record<string, unknown>;
  onChange: (json: Record<string, unknown>) => void;
  isBoss: boolean;
  dialoguePaths: string[];
  scenePaths: string[];
  onNavigate?: (path: string) => void;
}

export function CombatEventForm({ json, onChange, isBoss, dialoguePaths, scenePaths, onNavigate }: Props) {
  const waves = (json.waves as Wave[]) ?? [];
  const rewards = (json.rewards as Rewards) ?? {};
  const triggers = (json.dialogue_triggers as DialogueTriggers) ?? {};

  function setWaves(updated: Wave[]) {
    onChange({ ...json, waves: updated });
  }

  function setRewards(r: Rewards) {
    onChange({ ...json, rewards: r });
  }

  function setTriggers(t: DialogueTriggers) {
    onChange({ ...json, dialogue_triggers: t });
  }

  function addWave() {
    setWaves([...waves, { enemies: [{ scene: "", count: 1 }] }]);
  }

  function removeWave(i: number) {
    setWaves(waves.filter((_, idx) => idx !== i));
  }

  function updateWave(i: number, updated: Wave) {
    const next = [...waves];
    next[i] = updated;
    setWaves(next);
  }

  return (
    <div>
      {/* Waves */}
      <SectionHeader>Waves</SectionHeader>
      {waves.map((wave, i) => (
        <WaveCard
          key={i}
          index={i}
          wave={wave}
          scenePaths={scenePaths}
          isBoss={isBoss}
          onChange={(w) => updateWave(i, w)}
          onRemove={() => removeWave(i)}
          onNavigate={onNavigate}
        />
      ))}
      <button style={styles.addWaveBtn} onClick={addWave}>
        + Add Wave
      </button>

      {/* Dialogue triggers (boss or any combat with triggers) */}
      {(isBoss || waves.length > 0) && (
        <>
          <SectionHeader>Dialogue Triggers</SectionHeader>
          <TriggerRow label="on_start" value={triggers.on_start ?? ""} options={dialoguePaths} onChange={(v) => setTriggers({ ...triggers, on_start: v })} onNavigate={onNavigate} />
          <TriggerRow label="on_mid" value={triggers.on_mid ?? ""} options={dialoguePaths} onChange={(v) => setTriggers({ ...triggers, on_mid: v })} onNavigate={onNavigate} />
          <TriggerRow label="on_victory" value={triggers.on_victory ?? ""} options={dialoguePaths} onChange={(v) => setTriggers({ ...triggers, on_victory: v })} onNavigate={onNavigate} />
        </>
      )}

      {/* Rewards */}
      <SectionHeader>Rewards</SectionHeader>
      <div style={styles.row}>
        <label style={styles.label}>experience</label>
        <input type="number" step="1" value={rewards.experience ?? 0} onChange={(e) => setRewards({ ...rewards, experience: parseInt(e.target.value, 10) || 0 })} style={{ ...styles.numInput }} />
      </div>
      <div style={styles.row}>
        <label style={styles.label}>gold</label>
        <input type="number" step="1" value={rewards.gold ?? 0} onChange={(e) => setRewards({ ...rewards, gold: parseInt(e.target.value, 10) || 0 })} style={{ ...styles.numInput }} />
      </div>
    </div>
  );
}

function WaveCard({ index, wave, scenePaths, isBoss, onChange, onRemove, onNavigate }: {
  index: number;
  wave: Wave;
  scenePaths: string[];
  isBoss: boolean;
  onChange: (w: Wave) => void;
  onRemove: () => void;
  onNavigate?: (path: string) => void;
}) {
  const TRIGGER_OPTIONS = ["on_start", "on_mid", "on_victory"];

  function updateEnemy(i: number, e: Enemy) {
    const next = [...wave.enemies];
    next[i] = e;
    onChange({ ...wave, enemies: next });
  }

  function addEnemy() {
    onChange({ ...wave, enemies: [...wave.enemies, { scene: "", count: 1 }] });
  }

  function removeEnemy(i: number) {
    onChange({ ...wave, enemies: wave.enemies.filter((_, idx) => idx !== i) });
  }

  return (
    <div style={styles.waveCard}>
      <div style={styles.waveHeader}>
        <span style={styles.waveLabel}>Wave {index + 1}</span>
        <button style={styles.removeBtn} onClick={onRemove}>× Remove</button>
      </div>

      {/* Enemies */}
      {wave.enemies.map((enemy, i) => (
        <div key={i} style={styles.enemyRow}>
          <span style={styles.enemyIdx}>{i}</span>
          <div style={styles.sceneWrap}>
            <PathPicker
              value={enemy.scene}
              options={scenePaths}
              onChange={(v) => updateEnemy(i, { ...enemy, scene: v })}
              onNavigate={onNavigate}
              placeholder="(scene)"
            />
          </div>
          <span style={styles.countLabel}>×</span>
          <input
            type="number"
            min="1"
            step="1"
            value={enemy.count}
            onChange={(e) => updateEnemy(i, { ...enemy, count: parseInt(e.target.value, 10) || 1 })}
            style={styles.countInput}
          />
          <button style={styles.removeBtnSmall} onClick={() => removeEnemy(i)}>×</button>
        </div>
      ))}
      <button style={styles.addBtn} onClick={addEnemy}>+ Enemy</button>

      {/* on_clear_trigger (for boss waves that fire dialogue mid-combat) */}
      {isBoss && (
        <div style={styles.triggerRow}>
          <label style={styles.triggerLabel}>on_clear_trigger</label>
          <select
            style={styles.triggerSelect}
            value={wave.on_clear_trigger ?? ""}
            onChange={(e) => onChange({ ...wave, on_clear_trigger: e.target.value || undefined })}
          >
            <option value="">(none)</option>
            {TRIGGER_OPTIONS.map((t) => <option key={t} value={t}>{t}</option>)}
          </select>
        </div>
      )}
    </div>
  );
}

function TriggerRow({ label, value, options, onChange, onNavigate }: {
  label: string;
  value: string;
  options: string[];
  onChange: (v: string) => void;
  onNavigate?: (path: string) => void;
}) {
  return (
    <div style={styles.row}>
      <label style={styles.label}>{label}</label>
      <div style={{ flex: 1 }}>
        <PathPicker value={value} options={options} onChange={onChange} onNavigate={onNavigate} />
      </div>
    </div>
  );
}

function SectionHeader({ children }: { children: React.ReactNode }) {
  return <div style={styles.sectionHeader}>{children}</div>;
}

const styles = {
  sectionHeader: {
    fontSize: 11,
    color: "#666",
    textTransform: "uppercase" as const,
    letterSpacing: "0.06em",
    padding: "10px 0 6px",
    borderBottom: "1px solid #2a2a2a",
    marginBottom: 6,
  },
  waveCard: {
    border: "1px solid #2a2a3a",
    borderRadius: 4,
    padding: "8px 10px",
    marginBottom: 8,
    background: "#161620",
  },
  waveHeader: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 6,
  },
  waveLabel: { fontSize: 12, color: "#aaa", fontWeight: 600 },
  enemyRow: {
    display: "flex",
    alignItems: "center",
    gap: 6,
    marginBottom: 4,
  },
  enemyIdx: { color: "#555", fontSize: 11, width: 16, flexShrink: 0 },
  sceneWrap: { flex: 1, minWidth: 0 },
  countLabel: { color: "#666", fontSize: 13 },
  countInput: {
    background: "#222",
    border: "1px solid #444",
    color: "#eee",
    borderRadius: 3,
    padding: "3px 6px",
    fontSize: 13,
    width: 56,
    outline: "none",
  },
  addBtn: {
    background: "none",
    border: "1px dashed #333",
    color: "#666",
    cursor: "pointer",
    fontSize: 11,
    padding: "3px 8px",
    borderRadius: 3,
    marginTop: 4,
  },
  triggerRow: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    marginTop: 6,
    paddingTop: 6,
    borderTop: "1px solid #2a2a2a",
  },
  triggerLabel: { fontSize: 11, color: "#777", fontFamily: "monospace", width: 140 },
  triggerSelect: {
    background: "#222",
    border: "1px solid #444",
    color: "#eee",
    borderRadius: 3,
    padding: "2px 6px",
    fontSize: 12,
    outline: "none",
  },
  addWaveBtn: {
    display: "block",
    width: "100%",
    padding: "8px",
    background: "#1a1a2a",
    border: "1px dashed #333",
    color: "#666",
    cursor: "pointer",
    fontSize: 12,
    borderRadius: 4,
    marginBottom: 8,
  },
  row: {
    display: "flex",
    alignItems: "center",
    padding: "6px 0",
    gap: 8,
    borderBottom: "1px solid #222",
  },
  label: { width: 160, minWidth: 160, fontSize: 12, color: "#999", fontFamily: "monospace" },
  numInput: {
    background: "#222",
    border: "1px solid #444",
    color: "#eee",
    borderRadius: 3,
    padding: "3px 6px",
    fontSize: 13,
    width: 100,
    outline: "none",
  },
  removeBtn: {
    background: "none",
    border: "1px solid #422",
    color: "#844",
    cursor: "pointer",
    fontSize: 11,
    padding: "2px 6px",
    borderRadius: 3,
  },
  removeBtnSmall: {
    background: "none",
    border: "none",
    color: "#844",
    cursor: "pointer",
    fontSize: 16,
    lineHeight: 1,
    padding: "0 4px",
  },
} as const;
