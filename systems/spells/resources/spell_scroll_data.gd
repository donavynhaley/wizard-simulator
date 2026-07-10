class_name SpellScrollData
extends Resource

@export var display_name: String = ""
@export var charges: int = 1

@export var element_id: StringName = &""
@export var form_rune_ids: Array[StringName] = []
@export var effect_rune_ids: Array[StringName] = []
@export var modifier_rune_ids: Array[StringName] = []

@export var ink_id: StringName = &"standard"
@export var seal_id: StringName = &"cast_on_use"

@export var quality: float = 1.0
@export var misfire_chance: float = 0.0

@export var compiled_spell: CompiledSpellData


func is_castable() -> bool:
	return charges > 0 and compiled_spell != null
