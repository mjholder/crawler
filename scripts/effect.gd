class_name Effect
extends Resource

## `crit_mult` scales a critical hit (2.0 on crit, 1.0 otherwise). Rolled once per target by
## game.gd and passed to every effect of the hit so damage and stacks double together. Effects
## that don't deal damage or apply stacks ignore it.
func apply(_source: Node, _target: Node, _crit_mult: float = 1.0) -> void:
	push_warning("Effect.apply not implemented on %s" % get_script().resource_path)


## Tick variant. Called by Combatant._tick_statuses with the owning StatusInstance so a
## tick effect can read per-instance state (e.g. turns_remaining). Defaults to plain apply();
## only effects that need the instance (see BurstDamageEffect) override this.
func apply_tick(source: Node, target: Node, _instance: StatusInstance) -> void:
	apply(source, target)
