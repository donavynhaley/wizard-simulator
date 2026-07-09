class_name SpellDelivery
extends Node3D

var spell: CompiledSpellData
var cast_context: SpellCastContext


func initialize_spell(_spell: CompiledSpellData, _context: SpellCastContext) -> void:
	spell = _spell
	cast_context = _context


func build_hit_context(target: Node, hit_position: Vector3) -> SpellHitContext:
	var hit_context := SpellHitContext.new()
	hit_context.caster = cast_context.caster if cast_context != null else null
	hit_context.spell = spell
	hit_context.target = target
	hit_context.hit_position = hit_position
	hit_context.power = spell.power if spell != null else 1.0
	hit_context.element_id = spell.element.id if spell != null and spell.element != null else &""
	hit_context.tags = spell.tags.duplicate() if spell != null else []
	return hit_context


func apply_spell_effects(target: Node, hit_position: Vector3, event_id: StringName = &"spell_hit") -> void:
	if spell == null or target == null:
		return
	var hit_context := build_hit_context(target, hit_position)
	for effect_definition in spell.effects:
		if effect_definition == null or effect_definition.effect_script == null:
			continue
		var effect := effect_definition.effect_script.new() as SpellEffect
		if effect != null:
			effect.apply(target, hit_context)
	if target.has_method("receive_spell_event"):
		target.call("receive_spell_event", event_id, hit_context)
