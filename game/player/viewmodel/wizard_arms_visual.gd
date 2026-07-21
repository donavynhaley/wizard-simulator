extends Node3D

const SLEEVE_SHADER := preload("res://game/player/viewmodel/wizard_robe_sleeve.gdshader")
const SLEEVE_MESH_NAME := "WizardRobeSleeves"


func _ready() -> void:
	var sleeves := find_child(SLEEVE_MESH_NAME, true, false) as MeshInstance3D
	if sleeves == null:
		push_warning("Wizard robe sleeve mesh was not found in the imported arm model")
		return

	var robe_material := ShaderMaterial.new()
	robe_material.shader = SLEEVE_SHADER
	sleeves.material_override = robe_material
