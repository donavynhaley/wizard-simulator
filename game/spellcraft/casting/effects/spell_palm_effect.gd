class_name SpellPalmEffect
extends Node3D

## Placeholder held-spell visual: a glowing orb cupped in the palm plus a small
## tinted light. Real per-rune effects replace this via
## CastingController.spell_effect_bindings; whatever scene is spawned, the
## controller calls set_color() so the element system can recolor it later. Any
## replacement effect just needs to expose set_color(Color) to get tinting.

@export var color: Color = Color(0.55, 0.28, 1.0):
	set(value):
		color = value
		_apply_color()

## Slow spin so the orb reads as alive while held.
@export var spin_speed := 1.2

@onready var _orb: MeshInstance3D = $Orb
@onready var _light: OmniLight3D = get_node_or_null("PalmLight")


func _ready() -> void:
	_apply_color()


func _process(delta: float) -> void:
	rotate_y(spin_speed * delta)


## Called by the controller (and, later, the element system) to recolor the orb.
func set_color(new_color: Color) -> void:
	color = new_color


func _apply_color() -> void:
	if _orb != null:
		var mat := _orb.get_active_material(0) as StandardMaterial3D
		if mat != null:
			mat.albedo_color = color
			mat.emission = color
	if _light != null:
		_light.light_color = color
