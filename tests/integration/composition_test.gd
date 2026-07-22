extends SceneTree

const PLAYER_SCENE := preload("res://game/player/player.tscn")

var _fail: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as WizardPlayer
	root.add_child(player)
	await process_frame
	_check(player.get_node_or_null(^"Components/Locomotion") != null,
		"player composes locomotion as a child component")
	_check(player.get_node_or_null(^"Components/Look") != null,
		"player composes mouse look as a child component")
	_check(player.get_node_or_null(^"Head/Camera3D/Viewmodel/WizardHat") != null,
		"player wears the wizard hat in the camera viewmodel")
	var wizard_arms := player.get_node_or_null(
		^"Head/Camera3D/Viewmodel/WizardArms") as Node3D
	_check(wizard_arms != null,
		"player keeps the wizard arms in the camera viewmodel")
	if wizard_arms != null:
		_check_wizard_arm_remodel(wizard_arms)
	_check_evil_wizard_arm_variant()
	player.free()
	player = null
	await process_frame

	if _fail == 0:
		print("COMPOSITION TEST OK")
	else:
		print("COMPOSITION TEST FAILURES: ", _fail)
	quit(_fail)


func _check(ok: bool, message: String) -> void:
	if ok:
		print("[PASS] ", message)
	else:
		_fail += 1
		push_error("[FAIL] " + message)


func _check_wizard_arm_remodel(wizard_arms: Node3D) -> void:
	var skeleton := wizard_arms.get_node_or_null(^"arms/Skeleton3D") as Skeleton3D
	_check(skeleton != null, "remodeled arms retain their animation skeleton")
	if skeleton != null:
		_check(skeleton.get_bone_count() == 50,
			"remodeled arms preserve all 50 source bones")
		for bone_name in [
				&"bicep.r", &"forearm.r", &"wrist.r",
				&"bicep.l", &"forearm.l", &"wrist.l"]:
			_check(skeleton.find_bone(bone_name) >= 0,
				"remodeled arms preserve the %s bone" % bone_name)

	var sleeves := wizard_arms.find_child(
		"WizardRobeSleeves", true, false) as MeshInstance3D
	var nails := wizard_arms.find_child(
		"WizardPointedNails", true, false) as MeshInstance3D
	_check(sleeves != null, "remodeled arms include skinned robe sleeves")
	_check(nails != null, "remodeled arms include pointed fingernails")
	if sleeves != null:
		var sleeve_vertices := sleeves.mesh.surface_get_arrays(0)[
			Mesh.ARRAY_VERTEX] as PackedVector3Array
		_check(sleeve_vertices.size() >= 1240,
			"robe sleeves include sealed hanging cuff geometry")
		var sleeve_material := sleeves.material_override as ShaderMaterial
		_check(sleeve_material != null,
			"robe sleeves use the procedural fabric and sway material")
		if sleeve_material != null:
			var viewmodel_fill: Variant = sleeve_material.get_shader_parameter(
				&"viewmodel_fill")
			_check(viewmodel_fill is float and viewmodel_fill >= 0.3,
				"robe sleeve shader remains visible in unlit viewmodel areas")

	var hands := wizard_arms.find_child("arms_mesh", true, false) as MeshInstance3D
	_check(hands != null, "remodeled arms retain the skinned hand mesh")
	if hands != null:
		var hand_vertices := hands.mesh.surface_get_arrays(0)[
			Mesh.ARRAY_VERTEX] as PackedVector3Array
		_check(hand_vertices.size() <= 610,
			"hand mesh removes wrist vertices hidden beneath the robe cuffs")

	var right_animation := wizard_arms.get_node_or_null(
		^"AnimationPlayer") as AnimationPlayer
	var left_animation := wizard_arms.get_node_or_null(
		^"LeftAnimationPlayer") as AnimationPlayer
	_check(right_animation != null and right_animation.has_animation(&"spell_held"),
		"right-hand casting animations survive the remodel")
	_check(left_animation != null and left_animation.has_animation(&"spell_carry_left"),
		"left-hand casting animations survive the remodel")
	_check(left_animation != null and left_animation.has_animation(
		&"journal/journal_unhook_open_left"),
		"journal opening animation survives the remodel")


func _check_evil_wizard_arm_variant() -> void:
	var evil_scene := load(
		"res://assets/models/player/wizard_arms_evil.glb") as PackedScene
	_check(evil_scene != null, "evil wizard arms remain available as a model variant")
	if evil_scene == null:
		return
	var evil_arms := evil_scene.instantiate()
	var evil_skeleton := evil_arms.find_child(
		"Skeleton3D", true, false) as Skeleton3D
	var evil_nails := evil_arms.find_child(
		"WizardPointedNails", true, false) as MeshInstance3D
	_check(evil_skeleton != null and evil_skeleton.get_bone_count() == 50,
		"evil wizard arms preserve the shared 50-bone rig")
	_check(evil_nails != null, "evil wizard arms preserve the long claw mesh")
	evil_arms.free()
