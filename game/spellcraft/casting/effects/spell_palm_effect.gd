class_name SpellPalmEffect
extends Node3D

## Held-spell visual: a shader-driven energy orb cupped in the palm plus a tinted
## light. Per-rune/element spells drive the same spell_orb shader through
## different uniforms, so one shader covers every look. The controller calls
## set_color(); the element system will later push a full parameter set (flow,
## noise, energy, ...) via set_shader_param() for fire/ice/lightning/etc.

@export var color: Color = Color(0.55, 0.28, 1.0):
	set(value):
		color = value
		_apply_color()

## Slow spin so the orb reads as alive while held.
@export var spin_speed := 1.0

@onready var _orb: MeshInstance3D = $Orb
@onready var _light: OmniLight3D = get_node_or_null("PalmLight")

var _stability := 1.0
var _unrest_time := 0.0
var _base_light_energy := -1.0


func _ready() -> void:
	_apply_color()
	if _light != null:
		_base_light_energy = _light.light_energy


func _process(delta: float) -> void:
	rotate_y(spin_speed * delta)
	# Below the steady tier the palm light gutters: a sloppy verb reads as
	# barely holding its shape while it waits in the hand.
	if _light != null and _base_light_energy > 0.0 and _stability < 0.999:
		_unrest_time += delta * lerpf(11.0, 5.0, _stability)
		var unrest := 1.0 - _stability
		var gutter := 1.0 + (sin(_unrest_time * TAU)
			+ 0.5 * sin(_unrest_time * TAU * 1.9 + 0.7)) * 0.3 * unrest
		_light.light_energy = _base_light_energy * maxf(gutter, 0.15)


## Trace stability (0..1) from the controller; drives the gutter above.
func set_stability(value: float) -> void:
	_stability = clampf(value, 0.0, 1.0)
	if _light != null and _base_light_energy > 0.0 and _stability >= 0.999:
		_light.light_energy = _base_light_energy


## Called by the controller (and, later, the element system) to recolor the orb.
func set_color(new_color: Color) -> void:
	color = new_color


## Sets any spell_orb shader uniform directly; the element system uses this to
## push per-element looks (flow_speed, noise_scale, emission_energy, ...).
func set_shader_param(param: StringName, value: Variant) -> void:
	var mat := _orb_material()
	if mat != null:
		mat.set_shader_parameter(param, value)


func _apply_color() -> void:
	var mat := _orb_material()
	if mat != null:
		mat.set_shader_parameter(&"base_color", color)
		mat.set_shader_parameter(&"rim_color", color.lightened(0.45))
	if _light != null:
		_light.light_color = color


func _orb_material() -> ShaderMaterial:
	if _orb == null:
		return null
	return _orb.get_active_material(0) as ShaderMaterial
