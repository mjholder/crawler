export interface PropDescriptor {
  name: string;
  type: string;
  enum_ref?: string;
  enum_values?: Record<string, number>;
  element_type?: string;
  key_type?: string;
  value_type?: string;
  resource_type?: string;
}

export interface ClassDescriptor {
  script: string;
  extends: string;
  properties: PropDescriptor[];
}

export interface GameSchema {
  classes: Record<string, ClassDescriptor>;
  enums: Record<string, Record<string, number>>;
}

/** All properties for a class, parent props first (matches get_property_list). */
export function getAllProperties(
  className: string,
  schema: GameSchema
): PropDescriptor[] {
  const cls = schema.classes[className];
  if (!cls) return [];
  const parentProps = cls.extends ? getAllProperties(cls.extends, schema) : [];
  const ownNames = new Set(cls.properties.map((p) => p.name));
  return [
    ...parentProps.filter((p) => !ownNames.has(p.name)),
    ...cls.properties,
  ];
}

// Content types shown in the sidebar — each maps to a script_class and default new-file dir.
export const CONTENT_TYPES = [
  { label: "Weapons",      cls: "WeaponData",      dir: "res://resources/equipment/weapons/" },
  { label: "Armor & Rings",cls: "EquipmentData",   dir: "res://resources/equipment/armor/" },
  { label: "Attacks",      cls: "AttackData",       dir: "res://resources/attacks/" },
  { label: "Effects",      cls: "DamageEffect",     dir: "res://resources/effects/" },
  { label: "Classes",      cls: "PlayerClassData",  dir: "res://resources/classes/" },
  { label: "Shops",        cls: "ShopData",         dir: "res://resources/shops/" },
  { label: "Dialogues",    cls: "DialogueData",     dir: "res://resources/dialogue/" },
  { label: "Combat Events",  cls: "CombatEventData",    dir: "res://resources/events/combat/" },
  { label: "Boss Events",    cls: "BossEventData",      dir: "res://resources/events/boss/" },
  { label: "Dialogue Events",cls: "DialogueEventData",  dir: "res://resources/events/dialogue/" },
  { label: "Skill Checks",   cls: "SkillCheckEventData",dir: "res://resources/events/skill_check/" },
  { label: "Rest Events",    cls: "RestEventData",      dir: "res://resources/events/rest/" },
  { label: "Dungeon Floors", cls: "DungeonFloorData",  dir: "res://resources/dungeon_floors/" },
] as const;

export type ContentTypeCls = (typeof CONTENT_TYPES)[number]["cls"];

export const EVENT_TYPES = new Set([
  "CombatEventData",
  "BossEventData",
  "DialogueEventData",
  "SkillCheckEventData",
  "RestEventData",
]);
