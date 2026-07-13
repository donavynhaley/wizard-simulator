class_name MagicalFlame
extends Node3D

@export_group("Animation")
@export var core_root: Node3D
@export var flame_light: OmniLight3D
@export var core_sway_amount: float = 0.08
@export var core_pulse_amount: float = 0.025

@export_group("Light Flicker")
@export var light_energy: float = 0.85:
	set(value):
		light_energy = value
		_update_light()
@export var light_range: float = 2.2:
	set(value):
		light_range = value
		_update_light()
@export var flicker_strength: float = 0.16

var _age := 0.0


func _process(delta: float) -> void:
	_age += delta
	_update_core_motion()
	_update_light()


func set_light_scale(energy: float, light_radius: float) -> void:
	light_energy = energy
	light_range = light_radius
	_update_light()


func set_particle_density(ratio: float) -> void:
	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	for child in find_children("*", "GPUParticles3D", true, false):
		if child is GPUParticles3D:
			(child as GPUParticles3D).amount_ratio = clamped_ratio


func _update_core_motion() -> void:
	if core_root == null:
		return
	core_root.rotation.y = sin(_age * 0.8) * core_sway_amount
	core_root.scale = Vector3.ONE * (1.0 + sin(_age * 8.0) * core_pulse_amount)


func _update_light() -> void:
	if flame_light == null:
		return
	var slow_flicker := sin(_age * 7.7) * 0.65
	var quick_flicker := sin(_age * 18.9 + 0.7) * 0.35
	var flicker := 1.0 + (slow_flicker + quick_flicker) * flicker_strength
	flame_light.light_energy = light_energy * flicker
	flame_light.omni_range = light_range * (0.96 + flicker * 0.04)
