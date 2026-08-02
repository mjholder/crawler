class_name AttackPreview
extends RefCounted

## Shared preview computation for an attack/spell, feeding both the in-combat target overlay
## (target.tscn) and the action-button hover tooltip. Reuses StatExprEval so the previewed
## numbers match the runtime hit exactly: evaluated against SOURCE stats, non-crit (crit_mult
## 1.0), with NO target-side armor mitigation — the raw hit only (see
## journal/ideas/player-facing-legibility.md, "Damage/status preview design").

enum LineKind { DAMAGE, STATUS, HEAL, BUFF }

## One previewed contribution from a single effect on the attack.
class Line:
	var kind: AttackPreview.LineKind
	var label: String = ""          # humanized scaling expression, e.g. "STR × 0.5"
	var value: float = 0.0          # computed amount (damage/heal/buff magnitude)
	var status_data: StatusData = null
	var stacks: int = 1
	var pierce_ratio: float = 0.0   # DAMAGE lines only: 0–1 share of the hit that bypasses armor

var lines: Array[Line] = []

# Stat identifier -> compact abbreviation, for scaling-stat legibility in previews.
const _STAT_ABBR := {
	"strength": "STR", "defense": "DEF", "constitution": "CON",
	"agility": "AGI", "spirit": "SPI", "luck": "LCK",
	"max_health": "Max HP", "health": "HP",
}

const _ENUM_ABBR := {
	Enums.Stat.STRENGTH: "STR", Enums.Stat.DEFENSE: "DEF",
	Enums.Stat.CONSTITUTION: "CON", Enums.Stat.AGILITY: "AGI",
	Enums.Stat.SPIRIT: "SPI", Enums.Stat.LUCK: "LCK",
}


## Builds a preview for an AttackData or SpellData (both expose `effects`) evaluated against
## `source` (the acting combatant node — normally the player).
static func compute(action: Object, source: Node) -> AttackPreview:
	var preview := AttackPreview.new()
	if action == null:
		return preview
	var effects: Array = action.get("effects")
	if effects == null:
		return preview
	# Weapon-anatomy context so previewed damage matches the real hit: the composed power/scaling
	# expressions ("power + scale * scaling") need the acting weapon's numbers. Spells carry no
	# weapon context and evaluate flat, so only resolve it for weapon attacks.
	var context: Dictionary = {}
	if action is AttackData and source != null and source.has_method("weapon_context_for"):
		context = source.weapon_context_for(action)
	var eval := StatExprEval.new()
	for effect in effects:
		preview._append_effect(effect, eval, source, context)
	return preview


func _append_effect(effect: Resource, eval: StatExprEval, source: Node, context: Dictionary = {}) -> void:
	if effect == null:
		return
	# Order matters: BurstDamageEffect extends DamageEffect but is a per-turn tick, not a direct
	# hit, so it never contributes to the raw-hit preview even if it appears in `effects`.
	if effect is BurstDamageEffect:
		return
	if effect is StatusEffect:
		_add_status((effect as StatusEffect).status_data, (effect as StatusEffect).stacks)
	elif effect is GatedBleedEffect:
		_add_damage(effect.damage_expression, eval, source, effect.pierce_expression, context)
		_add_status(effect.status_data, 1)
	elif effect is ChainDamageEffect:
		_add_damage(effect.damage_expression, eval, source, effect.pierce_expression, context)
	elif effect is DamageEffect:
		_add_damage(effect.damage_expression, eval, source, effect.pierce_expression, context)
	elif effect is HealEffect:
		var heal := Line.new()
		heal.kind = LineKind.HEAL
		heal.value = eval.evaluate(effect.heal_expression, source, context)
		heal.label = humanize_expression(effect.heal_expression, context)
		lines.append(heal)
	elif effect is BuffEffect:
		var buff := Line.new()
		buff.kind = LineKind.BUFF
		buff.value = eval.evaluate(effect.amount_expression, source, context)
		buff.label = _ENUM_ABBR.get(effect.stat, "?")
		buff.stacks = effect.duration
		lines.append(buff)
	elif effect is BraceEffect:
		var brace := Line.new()
		brace.kind = LineKind.BUFF
		brace.value = eval.evaluate(effect.amount_expression, source, context)
		brace.label = "armor"
		lines.append(brace)


func _add_damage(expression: String, eval: StatExprEval, source: Node, pierce_expression: String = "0", context: Dictionary = {}) -> void:
	var line := Line.new()
	line.kind = LineKind.DAMAGE
	line.value = eval.evaluate(expression, source, context)
	line.label = humanize_expression(expression, context)
	line.pierce_ratio = clampf(eval.evaluate(pierce_expression, source, context), 0.0, 1.0)
	lines.append(line)


func _add_status(status_data: StatusData, stacks: int) -> void:
	if status_data == null:
		return
	var line := Line.new()
	line.kind = LineKind.STATUS
	line.status_data = status_data
	line.stacks = stacks
	lines.append(line)


## Sum of every direct-hit damage line — the number shown on the target overlay.
func total_damage() -> float:
	var total := 0.0
	for line in lines:
		if line.kind == LineKind.DAMAGE:
			total += line.value
	return total


## Status lines that carry a displayable StatusData (icon + name) — the overlay icon strip.
func status_lines() -> Array[Line]:
	var out: Array[Line] = []
	for line in lines:
		if line.kind == LineKind.STATUS and line.status_data != null:
			out.append(line)
	return out


## Per-effect breakdown for the action-button tooltip, one human-readable line each.
func tooltip_body() -> String:
	var parts: Array[String] = []
	for line in lines:
		match line.kind:
			LineKind.DAMAGE:
				var amount := str(int(round(line.value)))
				# A flat constant (label already equals the number) reads better without "= N".
				var text := "%s damage" % amount if line.label == amount else "%s = %s damage" % [line.label, amount]
				if line.pierce_ratio > 0.0:
					text += " · %d%% armor pierce" % int(round(line.pierce_ratio * 100.0))
				parts.append(text)
			LineKind.STATUS:
				parts.append(_status_line_text(line))
			LineKind.HEAL:
				parts.append("Heals %d" % int(round(line.value)))
			LineKind.BUFF:
				var sign := "+" if line.value >= 0.0 else ""
				var text := "%s%d %s" % [sign, int(round(line.value)), line.label]
				if line.stacks > 0:
					text += " (%d)" % line.stacks
				parts.append(text)
	return "\n".join(parts)


func _status_line_text(line: Line) -> String:
	var text := "Applies %s" % line.status_data.display_name
	if line.stacks > 1:
		text += " x%d" % line.stacks
	if line.status_data.duration != -1:
		text += " (%d)" % line.status_data.duration
	return text


## Rewrites a raw expression into a compact, player-facing form: stat identifiers become
## abbreviations (strength -> STR) and `*` becomes `×`. Surfaces the scaling stat without
## dumping source (item 5 of the legibility idea). When `context` carries weapon-anatomy values,
## the composed vars resolve too: `power`/`scaling` -> their numbers, `scale` -> the scaling stat
## abbreviation, so "power + scale * scaling" reads as "20 + STR × 0.5".
static func humanize_expression(expression: String, context: Dictionary = {}) -> String:
	var out := expression
	if not context.is_empty():
		# `coeff` is a multiplier: hide it entirely at its neutral 1.0 so the label reads as a plain
		# power term ("20 + STR × 0.5"), but surface it once a buff shifts it ("20 × 1.3 + STR × 0.5").
		var coeff_val: float = context.get("coeff", 1.0)
		if is_equal_approx(coeff_val, 1.0):
			out = out.replace(" * coeff", "").replace(" *coeff", "").replace("* coeff", "").replace("*coeff", "")
		else:
			out = _replace_word(out, "coeff", _fmt_num(coeff_val))
		# `scaling` before `scale` so the shorter name never clobbers the longer one.
		out = _replace_word(out, "scaling", _fmt_num(context.get("scaling", 0.0)))
		out = _replace_word(out, "scale", _ENUM_ABBR.get(context.get("scale_stat", -1), "scale"))
		out = _replace_word(out, "power", _fmt_num(context.get("power", 0.0)))
	for stat_name in _STAT_ABBR:
		out = _replace_word(out, stat_name, _STAT_ABBR[stat_name])
	out = out.replace("*", "×")
	return out


## Formats a coefficient/constant for a preview label: whole numbers lose the decimal (20, not 20.0).
static func _fmt_num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return str(snappedf(v, 0.01))


## Whole-word replace so "health" inside "max_health" isn't clobbered. Relies on iterating
## the longer key (max_health) — handled by _STAT_ABBR ordering — plus a boundary check.
static func _replace_word(text: String, word: String, replacement: String) -> String:
	var result := ""
	var search_from := 0
	while true:
		var idx := text.find(word, search_from)
		if idx == -1:
			result += text.substr(search_from)
			break
		var before_ok := idx == 0 or not _is_ident_char(text[idx - 1])
		var after_idx := idx + word.length()
		var after_ok := after_idx >= text.length() or not _is_ident_char(text[after_idx])
		result += text.substr(search_from, idx - search_from)
		if before_ok and after_ok:
			result += replacement
		else:
			result += word
		search_from = after_idx
	return result


static func _is_ident_char(c: String) -> bool:
	return c == "_" or (c.to_lower() != c.to_upper()) or (c >= "0" and c <= "9")
