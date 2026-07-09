class_name SpellRecipeOverride
extends Resource

@export var display_name: String = ""
@export var override_spell_id: StringName = &""

@export var required_element: StringName = &""
@export var required_form: StringName = &""
@export var required_effects: Array[StringName] = []
@export var required_modifiers: Array[StringName] = []

@export var override_visual_pack: SpellVisualPack
@export var override_delivery_scene: PackedScene


func matches(spell: CompiledSpellData) -> bool:
	if spell == null or spell.element == null or spell.form == null:
		return false
	if spell.element.id != required_element:
		return false
	if spell.form.id != required_form:
		return false
	for required_effect in required_effects:
		if not _spell_has_effect(spell, required_effect):
			return false
	for required_modifier in required_modifiers:
		if not _spell_has_modifier(spell, required_modifier):
			return false
	return true


func _spell_has_effect(spell: CompiledSpellData, effect_id: StringName) -> bool:
	for effect in spell.effects:
		if effect != null and effect.id == effect_id:
			return true
	return false


func _spell_has_modifier(spell: CompiledSpellData, modifier_id: StringName) -> bool:
	for modifier in spell.modifiers:
		if modifier != null and modifier.id == modifier_id:
			return true
	return false
