extends Node3D


func _ready() -> void:
	_build()


func _build() -> void:
	var brass := _material(Color(0.55, 0.38, 0.14), 0.52, 0.35)
	var iron := _material(Color(0.07, 0.075, 0.07), 0.72, 0.45)
	var blue := _emissive_material(Color(0.27, 0.62, 1.0), 0.85)
	var green := _emissive_material(Color(0.25, 0.95, 0.45), 0.7)
	var cork := _material(Color(0.36, 0.2, 0.08), 0.9)

	_add_cylinder("StillBase", 0.26, 0.22, Vector3(0.0, 0.1, 0.0), brass, 8)
	_add_cylinder("StillColumn", 0.07, 0.82, Vector3(0.0, 0.62, 0.0), brass, 8)
	var pipe := _add_cylinder("BentPipe", 0.035, 0.9, Vector3(0.38, 0.96, 0.0), brass, 6)
	pipe.rotation_degrees.z = 90.0
	_add_cylinder("ReceiverFlask", 0.18, 0.36, Vector3(0.83, 0.34, 0.0), blue, 8)
	_add_cylinder("ReceiverNeck", 0.075, 0.22, Vector3(0.83, 0.62, 0.0), blue, 8)
	_add_cylinder("SmallVial", 0.08, 0.3, Vector3(-0.55, 0.28, -0.12), green, 7)
	_add_cylinder("SmallVialCork", 0.085, 0.06, Vector3(-0.55, 0.46, -0.12), cork, 7)
	_add_box("BurnerFrame", Vector3(0.62, 0.08, 0.5), Vector3(0.0, -0.04, 0.0), iron)
	_add_cylinder("BurnerFlame", 0.09, 0.16, Vector3(0.0, 0.12, 0.0), _emissive_material(Color(1.0, 0.45, 0.13), 1.5), 6)


func _add_box(node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	add_child(mesh_instance)
	return mesh_instance


func _add_cylinder(node_name: String, radius: float, height: float, position: Vector3, material: Material, sides: int) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	add_child(mesh_instance)
	return mesh_instance


func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.58)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
