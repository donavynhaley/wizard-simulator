class_name EffectDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""

@export var effect_script: Script

@export var base_power: float = 1.0
@export var valid_target_tags: Array[StringName] = []
@export var effect_tags: Array[StringName] = []
