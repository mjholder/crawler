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

// The six v1 content types with their script_class names and default new-file directory
export const CONTENT_TYPES = [
  { label: "Weapons",      cls: "WeaponData",      dir: "res://resources/equipment/weapons/" },
  { label: "Armor & Rings",cls: "EquipmentData",   dir: "res://resources/equipment/armor/" },
  { label: "Attacks",      cls: "AttackData",       dir: "res://resources/attacks/" },
  { label: "Effects",      cls: "DamageEffect",     dir: "res://resources/effects/" },
  { label: "Classes",      cls: "PlayerClassData",  dir: "res://resources/classes/" },
  { label: "Shops",        cls: "ShopData",         dir: "res://resources/shops/" },
] as const;

export type ContentTypeCls = (typeof CONTENT_TYPES)[number]["cls"];
