class_name ArcaneBurst
extends Node3D

## Expanding, fading arcane-energy burst (reuses the spell_orb shader). Grows from
## a point to max_radius while fading its emission and alpha, then frees itself.
## Used for bolt impacts and ground-AoE detonations.

@export var max_radius := 1.2
@export var duration := 0.45
@export var start_energy := 6.0

@onready var _orb: MeshInstance3D = $Orb

var _age := 0.0
var _mat: ShaderMaterial


func _ready() -> void:
	if _orb != null:
		_mat = _orb.get_active_material(0) as ShaderMaterial
	scale = Vector3.ONE * 0.05


func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / duration, 0.0, 1.0)
	# Fast expansion that eases out.
	scale = Vector3.ONE * maxf(max_radius * ease(t, 0.35), 0.001)
	if _mat != null:
		_mat.set_shader_parameter(&"core_alpha", (1.0 - t) * 0.85)
		_mat.set_shader_parameter(&"emission_energy", lerpf(start_energy, 0.0, t))
	if t >= 1.0:
		queue_free()


## Tints the burst to match the spell's element (called by whatever spawns it).
func set_color(color: Color) -> void:
	if _mat == null and _orb != null:
		_mat = _orb.get_active_material(0) as ShaderMaterial
	if _mat != null:
		_mat.set_shader_parameter(&"base_color", color)
		_mat.set_shader_parameter(&"rim_color", color.lightened(0.45))


func set_shader_param(param: StringName, value: Variant) -> void:
	if _mat == null and _orb != null:
		_mat = _orb.get_active_material(0) as ShaderMaterial
	if _mat != null:
		_mat.set_shader_parameter(param, value)
