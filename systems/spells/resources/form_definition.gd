class_name FormDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""

@export var delivery_scene: PackedScene

@export var base_range: float = 10.0
@export var base_speed: float = 1.0
@export var base_radius: float = 1.0
@export var base_duration: float = 1.0

@export var default_tags: Array[StringName] = []
