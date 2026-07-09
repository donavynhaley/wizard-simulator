class_name InkDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""

@export var visual_pack: SpellVisualPack
@export var misfire_modifier: float = 0.0
@export var renown_multiplier: float = 1.0

@export var default_tags: Array[StringName] = []


func apply_to_spell(spell: CompiledSpellData) -> void:
	if spell == null:
		return
	for tag in default_tags:
		if not spell.tags.has(tag):
			spell.tags.append(tag)
