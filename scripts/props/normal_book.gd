extends Node3D

@export var cover_color: Color = Color(0.24, 0.11, 0.055)
@export var title: String = "Common Wizardry"


func _ready() -> void:
	_build()


func _build() -> void:
	var cover := _material(cover_color, 0.92)
	var pages := _material(Color(0.58, 0.5, 0.34), 0.98)
	var brass := _material(Color(0.58, 0.42, 0.16), 0.62, 0.22)
	_add_box("Cover", Vector3(0.48, 0.07, 0.34), Vector3.ZERO, cover)
	_add_box("Pages", Vector3(0.4, 0.028, 0.28), Vector3(0.03, 0.055, 0.0), pages)
	_add_box("Spine", Vector3(0.075, 0.085, 0.36), Vector3(-0.25, 0.01, 0.0), cover)
	_add_box("TitlePlate", Vector3(0.21, 0.012, 0.12), Vector3(0.03, 0.095, 0.0), brass)
	_add_box("Bookmark", Vector3(0.035, 0.014, 0.28), Vector3(0.16, 0.105, -0.01), _material(Color(0.45, 0.02, 0.025), 0.85))


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


func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
