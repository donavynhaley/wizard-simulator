class_name SpellCastSystem
extends RefCounted


func cast_scroll(scroll: SpellScrollData, context: SpellCastContext) -> Dictionary:
	if scroll == null:
		return _result(false, "No scroll to cast.", false)
	if scroll.charges <= 0:
		return _result(false, "The scroll is spent.", true)
	if scroll.compiled_spell == null:
		return _result(false, "The scroll has no spell.", false)
	if context == null or context.world == null:
		return _result(false, "No world to cast into.", false)

	context.source_scroll = scroll
	var spell := scroll.compiled_spell
	if randf() < scroll.misfire_chance:
		spell = MisfireGenerator.generate(spell)

	if spell == null:
		return _result(false, "The spell misfires into nothing.", true)

	var seal_result := spell.seal.handle_cast_request(spell, context)
	if bool(seal_result.get("execute_now", false)):
		var execute_error := execute_spell(spell, context)
		if not execute_error.is_empty():
			return _result(false, execute_error, false)

	if bool(seal_result.get("consumes_charge", true)):
		consume_charge(scroll)

	return _result(true, "Cast %s." % spell.display_name, scroll.charges <= 0)


func execute_spell(spell: CompiledSpellData, context: SpellCastContext) -> String:
	if spell.form == null or spell.form.delivery_scene == null:
		return "Spell form has no delivery scene."

	var delivery := spell.form.delivery_scene.instantiate()
	if not (delivery is Node):
		return "Spell delivery did not instantiate."

	context.world.add_child(delivery as Node)
	if delivery.has_method("initialize_spell"):
		delivery.call("initialize_spell", spell, context)
		return ""

	(delivery as Node).queue_free()
	return "Spell delivery is missing initialize_spell()."


func consume_charge(scroll: SpellScrollData) -> void:
	scroll.charges = maxi(scroll.charges - 1, 0)


func _result(cast: bool, status: String, spent: bool) -> Dictionary:
	return {
		"cast": cast,
		"status": status,
		"spent": spent,
	}
