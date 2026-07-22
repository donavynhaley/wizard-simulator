extends SceneTree

const LEVEL_SCENE := preload("res://game/world/levels/wizard_tower.tscn")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := LEVEL_SCENE.instantiate() as Node3D
	root.add_child(level)
	await process_frame
	await physics_frame
	await physics_frame

	var architecture := level.get_node_or_null(^"TowerArchitecture") as TowerArchitecture
	var player := level.get_node_or_null(^"Player") as WizardPlayer
	var terrain_mesh := level.get_node(^"WorldBlockout").find_child("terrain-ground", true, false)
	var terrain_body := terrain_mesh.find_child("*", true, false) as StaticBody3D
	_check(architecture != null, "level composes the Blender-authored tower architecture")
	_check(player != null, "level composes the player")
	if architecture == null or player == null:
		_finish()
		return

	var model_root := architecture.get_node_or_null(^"Model/WizardTowerArchitecture")
	_check(model_root != null, "tower wrapper contains the imported GLB root")
	if model_root != null:
		var import_extras := model_root.get_meta(&"extras", {}) as Dictionary
		_check(float(import_extras.get("exterior_radius_m", -1.0)) == 6.0,
			"tower preserves the approved six-meter exterior radius")
		_check(int(import_extras.get("above_ground_floor_count", -1)) == 4,
			"tower model declares four above-ground floors")
		_check(bool(import_extras.get("has_secret_basement", false)),
			"tower model declares its secret basement")
		_check(str(import_extras.get("masonry_style", "")) == "irregular_stone_with_aged_mortar",
			"tower model declares its irregular mortared masonry treatment")
		_check(is_equal_approx(float(import_extras.get("mortar_center_radius_m", 0.0)), 5.69),
			"mortar is centered within the depth of the irregular stones")
		_check(int(import_extras.get("door_count", -1)) == 1,
			"tower declares one actual doorway")
		_check(is_equal_approx(float(import_extras.get("floor_slab_radius_m", 0.0)), 5.72),
			"floor slabs extend to the surrounding wall structure")
		_check(float(import_extras.get("floor_wall_overlap_m", 0.0)) >= 0.129,
			"floor slabs overlap the mortar wall instead of leaving a perimeter gap")
		_check(float(import_extras.get("wall_collision_outer_radius_m", 0.0)) >= 6.02,
			"wall collision reaches the exterior face of the stones")
		_check(float(import_extras.get("wall_collision_inner_radius_m", 0.0)) <= 5.36,
			"wall collision still meets the interior face of the stones")
		_check(bool(import_extras.get("observatory_windows_fitted", false)),
			"observatory stained-glass openings are fitted to their frames")
		_check(float(import_extras.get("roof_height_m", 0.0)) >= 15.49,
			"tower roof has the approved taller pointed silhouette")
		_check(float(import_extras.get("roof_pitch_degrees", 0.0)) >= 66.5,
			"tower roof has a steep dark-fantasy pitch")
		_check(float(import_extras.get("roof_tip_radius_m", 1.0)) <= 0.011,
			"tower roof narrows to a sharp apex")
		for floor_index in range(1, 5):
			_check(model_root.find_child("floor_%d_mortar_backing" % floor_index, true, false) != null,
				"floor %d has a continuous opening-aware mortar backing" % floor_index)
			var wall_collision := model_root.find_child(
				"floor_%d_wall_collision" % floor_index, true, false) as StaticBody3D
			_check(wall_collision != null,
				"floor %d retains dedicated smooth wall collision" % floor_index)
			_check(wall_collision != null
					and wall_collision.find_child("*", true, false) is CollisionShape3D,
				"floor %d wall collision contains imported collision geometry" % floor_index)
		_check(model_root.find_child("basement_mortar_backing", true, false) != null,
			"basement masonry has continuous mortar backing")
		_check(model_root.find_child("basement_wall_collision", true, false) != null,
			"basement retains dedicated smooth wall collision")
		_check(model_root.find_child("stone_entry_frame", true, false) != null,
			"tower contains one dedicated stone entrance frame")
		_check(model_root.find_child("stone_door_frames", true, false) == null,
			"tower no longer contains the duplicated doorway assembly")
		var entry_door := model_root.find_child("warded_entry_door", true, false)
		_check(entry_door != null, "tower contains its single entrance door")
		if entry_door != null:
			var door_extras := entry_door.get_meta(&"extras", {}) as Dictionary
			_check(bool(door_extras.get("hinge_aligned", false)),
				"entrance door is authored around its frame hinge")
		var masonry := model_root.find_child("floor_1_masonry", true, false)
		_check(masonry != null, "tower contains the irregular exterior stone mesh")
		if masonry != null:
			var masonry_extras := masonry.get_meta(&"extras", {}) as Dictionary
			_check(bool(masonry_extras.get("mortar_backed", false)),
				"exterior stones identify their mortar backing")
			_check(float(masonry_extras.get("stone_width_max_m", 0.0))
					- float(masonry_extras.get("stone_width_min_m", 0.0)) >= 0.8,
				"exterior masonry declares a broad mix of stone sizes")
		_check(model_root.find_child("central_spiral_stair", true, false) != null,
			"tower model contains the central spiral staircase")
		_check(model_root.find_child("exterior_wooden_stair", true, false) != null,
			"observatory has its exterior wooden staircase")
		_check(model_root.find_child("scrying_crystal", true, false) != null,
			"observatory contains the central scrying crystal")
		_check(model_root.find_child("second_vessel_basin", true, false) != null,
			"basement contains the Second Vessel respawn basin")

	var closed_hatch := architecture.find_child("secret_hatch_closed", true, false) as MeshInstance3D
	var open_hatch := architecture.find_child("secret_hatch_open", true, false) as MeshInstance3D
	var blocker := architecture.get_node(^"SecretHatchBlocker/CollisionShape3D") as CollisionShape3D
	_check(not architecture.is_basement_revealed(), "basement starts undiscovered")
	_check(closed_hatch != null and closed_hatch.visible, "closed floor stone hides the basement stair")
	_check(open_hatch != null and not open_hatch.visible, "open hatch mesh starts hidden")
	_check(not blocker.disabled, "closed floor hatch blocks access before death")

	player.health.take_damage(player.health.maximum)
	await process_frame
	await process_frame
	await physics_frame
	_check(architecture.is_basement_revealed(), "first player death reveals the basement")
	_check(closed_hatch != null and not closed_hatch.visible, "death removes the disguised floor stone")
	_check(open_hatch != null and open_hatch.visible, "death exposes the opened floor hatch")
	_check(blocker.disabled, "revealed hatch no longer blocks the hidden staircase")
	_check(player.global_position.distance_to(architecture.basement_respawn.global_position) < 0.25,
		"death respawns the player inside the secret basement")
	_check(is_equal_approx(player.health.current, player.health.maximum),
		"the Second Vessel restores the player's health")
	_check(player.control_enabled(), "player control resumes after reconstruction")
	_check(terrain_body in player.get_collision_exceptions(),
		"revealed basement passage locally ignores the intersecting hill terrain")

	var hidden_stair_center := Vector3(3.45, 0.0, 1.45)
	player.global_position = Vector3(4.15, -2.62, 1.45)
	player.rotation = Vector3.ZERO
	player.locomotion.move_speed = 2.4
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	for _frame in 5:
		await physics_frame
	Input.action_press(&"move_forward")
	for _frame in 360:
		var stair_offset := player.global_position - hidden_stair_center
		stair_offset.y = 0.0
		var stair_angle := atan2(-stair_offset.z, stair_offset.x)
		var tangent := Vector3(-sin(stair_angle), 0.0, -cos(stair_angle))
		var radial_correction := stair_offset.normalized() * (0.70 - stair_offset.length()) * 2.5
		var desired_direction := (tangent + radial_correction).normalized()
		player.rotation.y = atan2(-desired_direction.x, -desired_direction.z)
		await physics_frame
		if player.global_position.y > 0.7:
			break
	Input.action_release(&"move_forward")
	print("Hidden stair climb final player position: ", player.global_position)
	_check(player.global_position.y > 0.7,
		"player can climb the revealed hidden stair back to the ground floor")
	var final_stair_offset := player.global_position - hidden_stair_center
	_check(Vector2(final_stair_offset.x, final_stair_offset.z).length() < 1.5,
		"hidden stair leads through the opened floor hatch")
	player.global_position = Vector3(6.2, 1.1, 0.0)
	await physics_frame
	_check(terrain_body not in player.get_collision_exceptions(),
		"terrain collision is restored before the player leaves the tower")

	player.health.take_damage(player.health.maximum)
	await process_frame
	await process_frame
	_check(architecture.is_basement_revealed(), "later deaths keep the basement permanently revealed")
	_check(player.global_position.distance_to(architecture.basement_respawn.global_position) < 0.05,
		"later deaths reuse the basement respawn point")

	player.global_position = Vector3(7.2, 1.05, 0.0)
	player.rotation.y = PI * 0.5
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	for _frame in 5:
		await physics_frame
	Input.action_press(&"move_forward")
	for _frame in 120:
		await physics_frame
	Input.action_release(&"move_forward")
	print("Exterior wall approach final player position: ", player.global_position)
	_check(player.global_position.x >= 6.25,
		"exterior wall collision meets the visible face of the stones")

	level.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("WIZARD TOWER REVEAL TEST OK")
	else:
		print("WIZARD TOWER REVEAL TEST FAILURES: ", _failures)
	quit(_failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		_failures += 1
		push_error("[FAIL] " + message)
