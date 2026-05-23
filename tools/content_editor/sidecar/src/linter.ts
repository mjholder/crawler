/**
 * Linter: validates expression strings and checks for dangling resource refs.
 *
 * Run against a resource's JSON representation (after io_read.gd).
 */
import { getEntry } from "./resource-index.js";

// Variables available in all expression contexts (from stat_expr_eval.gd)
const ALLOWED_VARS = new Set([
  "strength",
  "defense",
  "constitution",
  "agility",
  "spirit",
  "luck",
  "max_health",
  "health",
]);

// Fields whose values are expression strings that should be linted
const EXPRESSION_FIELDS = new Set([
  "damage_expression",
  "heal_expression",
  "amount_expression",
  "chance_expression",
  "guard_expression",
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

const MATH_BUILTINS = new Set([
  "abs", "ceil", "floor", "round", "min", "max", "clamp", "sqrt", "pow",
  "log", "exp", "sin", "cos", "tan", "PI", "INF", "NAN",
  "true", "false", "null",
]);
