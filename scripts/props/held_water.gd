class_name HeldWater
extends Node3D

@export var held_position: Vector3 = Vector3(0.0, -0.02, -0.04)
@export var held_rotation: Vector3 = Vector3(-0.2, 0.0, 0.0)
@export var held_scale: Vector3 = Vector3.ONE

var _is_held := false


func _ready() -> void:
	_build_visual()


func get_held_pose() -> Dictionary:
	return {
		"position": held_position,
		"rotation": held_rotation,
		"scale": held_scale,
	}


func get_display_name() -> String:
	return "Spring water"


func set_held(value: bool) -> void:
	_is_held = value
	if not _is_held:
		queue_free()


func _build_visual() -> void:
	var basin := MeshInstance3D.new()
	basin.name = "WaterSurface"
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.08
	mesh.radial_segments = 10
	mesh.rings = 4
	basin.mesh = mesh
	basin.material_override = _water_material()
	add_child(basin)

	var glint := MeshInstance3D.new()
	glint.name = "WaterGlint"
	var glint_mesh := SphereMesh.new()
	glint_mesh.radius = 0.055
	glint_mesh.height = 0.018
	glint_mesh.radial_segments = 6
	glint_mesh.rings = 2
	glint.mesh = glint_mesh
	glint.position = Vector3(0.075, 0.035, -0.025)
	glint.material_override = _glint_material()
	add_child(glint)


func _water_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.28, 0.74, 1.0, 0.68)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.22
	material.metallic = 0.0
	return material


func _glint_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 1.0, 1.0, 0.86)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.08
	return material
