class_name Effect
extends Resource

func apply(_source: Node, _target: Node) -> void:
	push_warning("Effect.apply not implemented on %s" % get_script().resource_path)


## Tick variant. Called by Combatant._tick_statuses with the owning StatusInstance so a
## tick effect can read per-instance state (e.g. turns_remaining). Defaults to plain apply();
## only effects that need the instance (see BurstDamageEffect) override this.
func apply_tick(source: Node, target: Node, _instance: StatusInstance) -> void:
	apply(source, target)
