class_name RendEffect
extends SpellEffect


func apply(target: Node, context: SpellHitContext) -> void:
	if target == null:
		return
	if target.has_method("take_damage"):
		target.call("take_damage", {
			"amount": context.power,
			"element": context.element_id,
			"source": context.caster,
			"tags": context.tags,
		})
	if target.has_method("receive_spell_event"):
		target.call("receive_spell_event", &"rended", context)
