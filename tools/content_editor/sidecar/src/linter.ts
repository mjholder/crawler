/**
 * Linter: validates expression strings and checks for dangling resource refs.
 *
 * Run against a resource's JSON representation (after io_read.gd).
 */
import { getEntry } from "./resource-index.js";

// Variables available in all expression contexts (from stat_expr_eval.gd)
const ALLOWED_VARS = new Set([
  // Bearer stats — present in every expression context.
  "strength",
  "defense",
  "constitution",
  "agility",
  "spirit",
  "luck",
  "max_health",
  "health",
  // Weapon-anatomy context — supplied for weapon basic-attack effects (game.gd builds it
  // via player.weapon_context_for). The uniform damage form is `power * coeff + scale * scaling`:
  //   power   — the weapon's flat authored power (WeaponData.power, composed with smithing)
  //   scaling — the weapon's stat coefficient (WeaponData.scaling, composed with rarity)
  //   scale   — the bearer's effective value of the weapon's declared scaling_stat
  //   coeff   — the per-attack shape knob (AttackData.power_coefficient, 1.0 default; buffable)
  // These are undefined for non-weapon expressions (spells, self-costs, status ticks); the eval
  // treats a missing var as 0.0 (coeff as 1.0), so only weapon-attack effects should use them.
  "power",
  "scaling",
  "scale",
  "coeff",
]);

// Fields whose values are expression strings that should be linted
const EXPRESSION_FIELDS = new Set([
  "damage_expression",
  "heal_expression",
  "amount_expression",
  "chance_expression",
  "guard_expression",
  "pierce_expression",
]);

export interface LintError {
  path: string; // JSON path to the offending value, e.g. "proc_effects[0].effect.damage_expression"
  message: string;
}

export function lintResource(data: unknown): LintError[] {
  const errors: LintError[] = [];
  walk(data, "", errors);
  return errors;
}

function walk(node: unknown, path: string, errors: LintError[]): void {
  if (node == null || typeof node !== "object") return;

  if (Array.isArray(node)) {
    node.forEach((item, i) => walk(item, `${path}[${i}]`, errors));
    return;
  }

  const obj = node as Record<string, unknown>;

  // External resource ref — check it resolves
  if ("__ref" in obj || "__uid" in obj) {
    const uid = obj["__uid"] as string | undefined;
    const ref = obj["__ref"] as string | undefined;
    const key = uid ?? ref ?? "";
    if (key && !getEntry(key)) {
      errors.push({
        path,
        message: `Dangling reference: ${key} does not exist in the index`,
      });
    }
    return; // don't recurse into ref objects
  }

  for (const [key, value] of Object.entries(obj)) {
    if (key.startsWith("_")) continue;

    const childPath = path ? `${path}.${key}` : key;

    if (EXPRESSION_FIELDS.has(key) && typeof value === "string") {
      const exprErrors = lintExpression(value, childPath);
      errors.push(...exprErrors);
      if (key === "pierce_expression") {
        errors.push(...lintPierceRange(value, childPath));
      }
    } else {
      walk(value, childPath, errors);
    }
  }
}

function lintExpression(expr: string, path: string): LintError[] {
  const errors: LintError[] = [];
  // Tokenise: extract bare identifiers (not preceded by a dot or quote)
  const IDENT_RE = /(?<![.'"a-zA-Z0-9_])([a-zA-Z_][a-zA-Z0-9_]*)/g;
  for (const m of expr.matchAll(IDENT_RE)) {
    const ident = m[1];
    // Skip numeric-adjacent tokens and common math functions
    if (MATH_BUILTINS.has(ident)) continue;
    if (!ALLOWED_VARS.has(ident)) {
      errors.push({
        path,
        message: `Unknown variable "${ident}" in expression "${expr}"`,
      });
    }
  }
  return errors;
}

// pierce_expression is a 0–1 ratio (the share of a hit that bypasses armor). When it's authored
// as a plain numeric literal, flag values outside [0, 1] — catches leftover flat-armor pierce
// values (e.g. "5") from before the percentage-split migration. Non-constant expressions
// (e.g. "strength * 0.3") are left to the author; only the runtime clamp guards those.
function lintPierceRange(expr: string, path: string): LintError[] {
  const trimmed = expr.trim();
  if (!/^-?\d+(\.\d+)?$/.test(trimmed)) return [];
  const n = Number(trimmed);
  if (n < 0 || n > 1) {
    return [
      {
        path,
        message: `pierce_expression "${expr}" is out of range: it is now a 0–1 ratio (0.25/0.5/0.75/1.0), not a flat armor amount`,
      },
    ];
  }
  return [];
}

const MATH_BUILTINS = new Set([
  "abs", "ceil", "floor", "round", "min", "max", "clamp", "sqrt", "pow",
  "log", "exp", "sin", "cos", "tan", "PI", "INF", "NAN",
  "true", "false", "null",
]);
