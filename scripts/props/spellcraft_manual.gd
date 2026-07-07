class_name SpellcraftManual
extends Node3D

@export_multiline var page_one: String = "A spell is runes in agreement: one Element (what it is), one Shape (how it travels), and if you dare, Behaviors, a Trigger, and Modifiers. Socket the stones at a bench and channel the crystal."
@export_multiline var page_two: String = "Every rune adds instability. Past a point the spell picks up quirks; past a further point the forge bites back. The same runes always forge the same spell, so write down what you learn."
@export_multiline var page_three: String = "Starter example: Fire + Orb + Bounce + Explode forges the Bouncing Detonator. A finished spell lives on a scroll; hold the scroll to cast it, and spend its charges wisely."


func _ready() -> void:
	_build()


func get_pages() -> Array[String]:
	return [page_one, page_two, page_three]


func _build() -> void:
	var cover := _material(Color(0.12, 0.035, 0.05), 0.95)
	var page := _material(Color(0.62, 0.55, 0.39), 0.98)
	var ink := _material(Color(0.035, 0.025, 0.055), 1.0)
	var brass := _material(Color(0.62, 0.45, 0.18), 0.55, 0.35)

	var left_cover := _add_box("LeftCover", Vector3(0.48, 0.045, 0.62), Vector3(-0.25, 0.0, 0.0), cover)
	left_cover.rotation_degrees.z = 5.0
	var right_cover := _add_box("RightCover", Vector3(0.48, 0.045, 0.62), Vector3(0.25, 0.0, 0.0), cover)
	right_cover.rotation_degrees.z = -5.0
	var left_page := _add_box("LeftPage", Vector3(0.42, 0.025, 0.54), Vector3(-0.23, 0.045, 0.0), page)
	left_page.rotation_degrees.z = 5.0
	var right_page := _add_box("RightPage", Vector3(0.42, 0.025, 0.54), Vector3(0.23, 0.045, 0.0), page)
	right_page.rotation_degrees.z = -5.0
	_add_box("SpineHinge", Vector3(0.08, 0.08, 0.66), Vector3(0.0, 0.0, 0.0), brass)
	for i in 4:
		_add_box("ManualLineLeft%d" % i, Vector3(0.26 - i * 0.025, 0.012, 0.018), Vector3(-0.23, 0.072, -0.18 + i * 0.11), ink)
		_add_box("ManualLineRight%d" % i, Vector3(0.24 - i * 0.02, 0.012, 0.018), Vector3(0.23, 0.072, -0.18 + i * 0.11), ink)
	_add_box("MagicDiagram", Vector3(0.16, 0.014, 0.16), Vector3(0.23, 0.078, 0.18), brass)
	_add_label("PageTextLeft", "Element + Shape", Vector3(-0.23, 0.09, -0.06), -5.0)
	_add_label("PageTextRight", "Trigger + Modifier", Vector3(0.23, 0.09, -0.06), 5.0)


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


func _add_label(node_name: String, text: String, position: Vector3, roll_degrees: float) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.font_size = 18
	label.pixel_size = 0.004
	label.modulate = Color(0.04, 0.03, 0.045)
	label.position = position
	label.rotation_degrees = Vector3(-90.0, 0.0, roll_degrees)
	add_child(label)
	return label


func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
