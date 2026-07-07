extends Node3D

@export var iron_color: Color = Color(0.055, 0.06, 0.055)
@export var glow_color: Color = Color(0.25, 1.0, 0.48)


func _ready() -> void:
	_build()


func _build() -> void:
	var iron := _material(iron_color, 0.78, 0.35)
	var glow := _emissive_material(glow_color, 1.2)
	var brass := _material(Color(0.56, 0.39, 0.15), 0.55, 0.35)

	_add_cylinder("Bowl", 0.55, 0.68, Vector3.ZERO, iron, 10)
	_add_cylinder("Rim", 0.68, 0.08, Vector3(0.0, 0.38, 0.0), iron, 10)
	_add_cylinder("PotionSurface", 0.47, 0.035, Vector3(0.0, 0.45, 0.0), glow, 12)
	_add_cylinder("InnerShadow", 0.38, 0.025, Vector3(0.0, 0.468, 0.0), _material(Color(0.02, 0.03, 0.02), 1.0), 10)

	for i in 3:
		var angle := TAU * float(i) / 3.0
		_add_cylinder("Foot%d" % i, 0.075, 0.28, Vector3(cos(angle) * 0.38, -0.46, sin(angle) * 0.38), iron, 6)

	var left_handle := _add_cylinder("LeftHandle", 0.045, 0.58, Vector3(-0.65, 0.08, 0.0), iron, 6)
	left_handle.rotation_degrees.z = 90.0
	var right_handle := _add_cylinder("RightHandle", 0.045, 0.58, Vector3(0.65, 0.08, 0.0), iron, 6)
	right_handle.rotation_degrees.z = 90.0

	for i in 4:
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		_add_box("BrassRivet%d" % i, Vector3(0.08, 0.08, 0.035), Vector3(cos(angle) * 0.54, 0.18, sin(angle) * 0.54), brass)


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
	var material := _material(color, 0.6)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
