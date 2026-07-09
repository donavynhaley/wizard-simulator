class_name MendEffect
extends SpellEffect


func apply(target: Node, context: SpellHitContext) -> void:
	if target == null:
		return
	if target.has_method("heal"):
		target.call("heal", context.power)
	if target.has_method("repair"):
		target.call("repair", context.power)
	if target.has_method("receive_spell_event"):
		target.call("receive_spell_event", &"mended", context)
