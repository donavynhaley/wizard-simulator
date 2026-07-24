extends Node3D

const SLEEVE_SHADER := preload("res://game/player/viewmodel/wizard_robe_sleeve.gdshader")
const SLEEVE_MESH_NAME := "WizardRobeSleeves"
const VIEWMODEL_FILL := 0.45


func _ready() -> void:
	var sleeves := find_child(SLEEVE_MESH_NAME, true, false) as MeshInstance3D
	if sleeves == null:
		push_warning("Wizard robe sleeve mesh was not found in the imported arm model")
		return

	var robe_material := ShaderMaterial.new()
	robe_material.shader = SLEEVE_SHADER
	robe_material.set_shader_parameter(&"viewmodel_fill", VIEWMODEL_FILL)
	sleeves.material_override = robe_material
