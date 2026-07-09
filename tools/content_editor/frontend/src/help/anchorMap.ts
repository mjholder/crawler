const CLASS_TO_ANCHOR: Record<string, string> = {
  WeaponData: "weapondata",
  EquipmentData: "equipmentdata",
  AttackData: "attackdata",
  DamageEffect: "effects",
  HealEffect: "effects",
  BuffEffect: "effects",
  StatusEffect: "effects",
  BurstDamageEffect: "effects",
  ChainDamageEffect: "effects",
  GatedBleedEffect: "effects",
  BraceEffect: "effects",
  Effect: "effects",
  ConditionalModifier: "conditionalmodifier",
  ProcDef: "procdef",
  StatusData: "statusdata",
  ConsumableData: "consumabledata",
  PlayerClassData: "playerclassdata",
  ShopData: "shopdata",
  BlessingData: "blessingdata",
  SpellData: "spelldata",
  TomeData: "tomedata",
  DungeonFloorData: "dungeonfloordata",
  FloorSlot: "floorslot",
  WeightedEntry: "weightedentry",
};

const EVENT_ANCHOR: Record<string, string> = {
  DialogueData: "dialogue-editor",
  CombatEventData: "combat-and-boss-events",
  BossEventData: "combat-and-boss-events",
  SkillCheckEventData: "skill-check-events",
  RestEventData: "rest-events",
  DialogueEventData: "dialogue-events",
  FloorSlotBuilder: "floorslot",
};

export function anchorForView(
  selectedType: string | null,
  viewMode: "form" | "table",
  isCustomView: boolean,
  hasPath: boolean
): string {
  if (!selectedType) return "sidebar";
  // Events and dialogue are custom views but now also have a table; the table help
  // applies whenever we're in table mode.
  if (viewMode === "table") return "table-view";
  if (isCustomView) return EVENT_ANCHOR[selectedType] ?? "event-editor";
  if (!hasPath) return "form-view";
  return CLASS_TO_ANCHOR[selectedType] ?? "form-view";
}
