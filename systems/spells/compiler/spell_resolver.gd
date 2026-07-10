class_name SpellResolver
extends RefCounted

@export var overrides: Array[SpellRecipeOverride] = []


func load_overrides_from_directory(directory_path: String) -> Error:
	overrides.clear()
	var dir := DirAccess.open(directory_path)
	if dir == null:
		return DirAccess.get_open_error()

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "%s/%s" % [directory_path.trim_suffix("/"), file_name]
			var resource := ResourceLoader.load(path)
			if resource is SpellRecipeOverride:
				overrides.append(resource as SpellRecipeOverride)
		file_name = dir.get_next()
	dir.list_dir_end()
	return OK


func resolve_identity(spell: CompiledSpellData) -> void:
	var override := _find_matching_override(spell)
	if override != null:
		_apply_override(spell, override)
		return

	spell.spell_id = _generate_generic_spell_id(spell)
	spell.display_name = _generate_generic_display_name(spell)


func _find_matching_override(spell: CompiledSpellData) -> SpellRecipeOverride:
	for override in overrides:
		if override != null and override.matches(spell):
			return override
	return null


func _apply_override(spell: CompiledSpellData, override: SpellRecipeOverride) -> void:
	spell.spell_id = override.override_spell_id
	spell.display_name = override.display_name
	if override.override_delivery_scene != null and spell.form != null:
		var unique_form := spell.form.duplicate(true) as FormDefinition
		unique_form.delivery_scene = override.override_delivery_scene
		spell.form = unique_form
	if override.override_visual_pack != null and not spell.tags.has(&"authored_visuals"):
		spell.tags.append(&"authored_visuals")


func _generate_generic_spell_id(spell: CompiledSpellData) -> StringName:
	var effect_name := "effect"
	if not spell.effects.is_empty() and spell.effects[0] != null:
		effect_name = String(spell.effects[0].id)
	return StringName("%s_%s_%s" % [
		String(spell.element.id) if spell.element != null else "element",
		String(spell.form.id) if spell.form != null else "form",
		effect_name,
	])


func _generate_generic_display_name(spell: CompiledSpellData) -> String:
	var effect_name := "Spell"
	if not spell.effects.is_empty() and spell.effects[0] != null:
		effect_name = spell.effects[0].display_name
	return "%s %s %s" % [
		spell.element.display_name if spell.element != null else "Element",
		spell.form.display_name if spell.form != null else "Form",
		effect_name,
	]
