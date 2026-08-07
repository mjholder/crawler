export type FieldPredicate = (propName: string, data: Record<string, unknown>) => boolean;

// Per-class field visibility predicates.  When a class is listed here, only
// props that pass the predicate are shown in InlineResourceEditor.  Other
// classes render all props unconditionally (predicate absent = show all).
export const FIELD_VISIBILITY: Record<string, FieldPredicate> = {
  FloorSlot: (propName, data) => {
    // FloorSlot is a tagged union — only the fields relevant to the current
    // type value should be visible.  Default to FIXED (0) to match GDScript.
    const type = typeof data.type === "number" ? data.type : 0;
    switch (propName) {
      case "type":       return true;
      case "event":      return type === 0; // FIXED
      case "event_type": return type === 1; // RANDOM_TYPE
      case "entries":    return type === 2; // WEIGHTED
      default:           return true;
    }
  },

  WeightedEntry: (propName, data) => {
    // WeightedEntry resolves via `event` if non-null, else via `event_type`.
    // Hide whichever branch isn't active so both don't show simultaneously.
    if (propName === "event_type") return data.event == null;
    return true;
  },

  WeaponData: (propName, data) => {
    // The two offhand movesets only apply in specific configurations:
    //  - as_offhand_attacks: this weapon's moveset while IT sits in the offhand,
    //    so only relevant when it may be equipped there (hand_restriction EITHER = 2).
    //  - locked_offhand_attacks: actions granted to the locked offhand while this
    //    two-hander holds the mainhand, so only relevant when is_two_handed.
    switch (propName) {
      case "as_offhand_attacks":     return data.hand_restriction === 2; // EITHER
      case "locked_offhand_attacks": return data.is_two_handed === true;
      default:                       return true;
    }
  },

  PatronSaintData: (propName) => {
    // A saint's lineage_id and tiers are owned by the dedicated LineageBuilder
    // panel (rendered above the generic fields), so hide them from the generic
    // form to avoid double-editing.
    return propName !== "lineage_id" && propName !== "tiers";
  },
};

// Override the widget used for a specific field, bypassing the type-based
// dispatch in FieldRenderer.  Key format: "ClassName.propName"  Value: a widget
// id the renderer knows how to build.  Registered here (as plain strings, not
// components) so this module stays free of import cycles with FieldRenderer.
export const WIDGET_OVERRIDES: Record<string, string> = {
  "BlessingData.subscriptions": "subscriptions",
  "StatusData.subscriptions": "subscriptions",
};

export function getWidgetOverride(cls: string | undefined, propName: string): string | undefined {
  if (!cls) return undefined;
  return WIDGET_OVERRIDES[`${cls}.${propName}`];
}

// Override the directory scanned for a Resource-typed field.
// Key format: "ClassName.propName"  Value: res:// directory path (trailing slash).
export const FIELD_DIR_OVERRIDES: Record<string, string> = {
  "FloorSlot.event": "res://resources/events/",
  "WeightedEntry.event": "res://resources/events/",
  "PatronSaintData.tiers": "res://resources/patron_saints/tiers/",
};

export function getFieldDirOverride(cls: string, propName: string): string | undefined {
  return FIELD_DIR_OVERRIDES[`${cls}.${propName}`];
}
