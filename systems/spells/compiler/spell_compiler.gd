class_name SpellCompiler
extends RefCounted

@export_dir var element_directory: String = "res://data/spells/elements"
@export_dir var form_directory: String = "res://data/spells/forms"
@export_dir var effect_directory: String = "res://data/spells/effects"
@export_dir var modifier_directory: String = "res://data/spells/modifiers"
@export_dir var ink_directory: String = "res://data/spells/inks"
@export_dir var seal_directory: String = "res://data/spells/seals"
@export_dir var override_directory: String = "res://data/spells/overrides"

var spell_resolver: SpellResolver


func compile_scroll(scroll: SpellScrollData) -> CompiledSpellData:
	if scroll == null:
		return null

	var compiled := CompiledSpellData.new()
	compiled.element = _load_definition(element_directory, scroll.element_id) as ElementDefinition
	compiled.form = _load_definition(form_directory, _first_id(scroll.form_rune_ids)) as FormDefinition
	compiled.ink = _load_definition(ink_directory, scroll.ink_id) as InkDefinition
	compiled.seal = _load_definition(seal_directory, scroll.seal_id) as SealDefinition

	for effect_id in scroll.effect_rune_ids:
		var effect := _load_definition(effect_directory, effect_id) as EffectDefinition
		if effect != null:
			compiled.effects.append(effect)

	for modifier_id in scroll.modifier_rune_ids:
		var modifier := _load_definition(modifier_directory, modifier_id) as ModifierDefinition
		if modifier != null:
			compiled.modifiers.append(modifier)

	if compiled.element == null or compiled.form == null or compiled.effects.is_empty() or compiled.ink == null or compiled.seal == null:
		return null

	_apply_base_stats(compiled)
	_apply_quality(compiled, scroll.quality)
	_apply_tags(compiled)

	compiled.ink.apply_to_spell(compiled)
	scroll.misfire_chance = maxf(0.0, scroll.misfire_chance + compiled.ink.misfire_modifier)

	for modifier in compiled.modifiers:
		modifier.apply_to_spell(compiled)

	if spell_resolver == null:
		spell_resolver = SpellResolver.new()
		var error := spell_resolver.load_overrides_from_directory(override_directory)
		if error != OK and error != ERR_DOES_NOT_EXIST and error != ERR_FILE_NOT_FOUND:
			push_warning("Could not load spell overrides from %s: %s" % [override_directory, error_string(error)])
	spell_resolver.resolve_identity(compiled)

	scroll.compiled_spell = compiled
	scroll.display_name = _scroll_display_name(compiled)
	return compiled


func _apply_base_stats(spell: CompiledSpellData) -> void:
	spell.power = 1.0
	spell.speed = spell.form.base_speed
	spell.radius = spell.form.base_radius
	spell.duration = spell.form.base_duration
	spell.range = spell.form.base_range


func _apply_quality(spell: CompiledSpellData, quality: float) -> void:
	var clamped_quality := clampf(quality, 0.0, 1.0)
	var quality_multiplier := lerpf(0.75, 1.25, clamped_quality)
	spell.power *= quality_multiplier
	spell.radius *= lerpf(0.9, 1.1, clamped_quality)
	spell.duration *= lerpf(0.85, 1.15, clamped_quality)

	if clamped_quality >= 0.9 and not spell.tags.has(&"high_quality"):
		spell.tags.append(&"high_quality")
	if clamped_quality < 0.6 and not spell.tags.has(&"sloppy"):
		spell.tags.append(&"sloppy")


func _apply_tags(spell: CompiledSpellData) -> void:
	_append_unique_tags(spell.tags, spell.element.default_tags)
	_append_unique_tags(spell.tags, spell.form.default_tags)
	for effect in spell.effects:
		_append_unique_tags(spell.tags, effect.effect_tags)


func _append_unique_tags(target: Array[StringName], source: Array[StringName]) -> void:
	for tag in source:
		if not target.has(tag):
			target.append(tag)


func _load_definition(directory_path: String, id: StringName) -> Resource:
	if id == &"":
		return null
	var direct_path := "%s/%s_%s.tres" % [
		directory_path.trim_suffix("/"),
		_definition_prefix(directory_path),
		String(id),
	]
	if ResourceLoader.exists(direct_path):
		return ResourceLoader.load(direct_path)

	var dir := DirAccess.open(directory_path)
	if dir == null:
		return null
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "%s/%s" % [directory_path.trim_suffix("/"), file_name]
			var resource := ResourceLoader.load(path)
			if resource != null and resource.get("id") == id:
				dir.list_dir_end()
				return resource
		file_name = dir.get_next()
	dir.list_dir_end()
	return null


func _definition_prefix(directory_path: String) -> String:
	var folder := directory_path.get_file()
	if folder.ends_with("s"):
		return folder.trim_suffix("s")
	return folder


func _first_id(ids: Array[StringName]) -> StringName:
	if ids.is_empty():
		return &""
	return ids[0]


func _scroll_display_name(spell: CompiledSpellData) -> String:
	var name := spell.display_name
	if spell.ink != null and spell.ink.id != &"standard":
		name = "%s %s" % [spell.ink.display_name, name]
	return "%s Scroll" % name
