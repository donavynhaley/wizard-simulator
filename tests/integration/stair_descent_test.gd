extends SceneTree

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := (load("res://game/world/levels/wizard_tower.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame

	var player := scene.get_node("Player") as CharacterBody3D
	var stair_visual := scene.find_child("central_spiral_stair", true, false) as MeshInstance3D
	if stair_visual == null:
		push_error("[FAIL] descent test needs the central_spiral_stair mesh")
		quit(1)
		return
	# The tower no longer sits at the world origin (2026-07-21 scene split), so
	# derive the spiral axis from the stair mesh instead of hardcoding it.
	var stair_aabb := stair_visual.get_aabb()
	var spiral_center: Vector3 = stair_visual.global_transform * stair_aabb.get_center()
	var base_y := spiral_center.y - stair_aabb.size.y * 0.5
	var start_angle := 0.1
	player.global_position = Vector3(
		spiral_center.x + cos(start_angle) * 1.25,
		base_y + 4.75,
		spiral_center.z - sin(start_angle) * 1.25)
	for index in 30:
		await physics_frame
		if player.is_on_floor():
			break

	var start_position := player.global_position
	var falling_frames := 0
	var airborne_frames := 0
	Input.action_press("move_forward")
	for index in 300:
		var offset := Vector3(player.global_position.x - spiral_center.x, 0.0,
			player.global_position.z - spiral_center.z)
		var angle := atan2(-offset.z, offset.x)
		var tangent := Vector3(sin(angle), 0.0, cos(angle))
		var radial_correction := offset.normalized() * (1.25 - offset.length()) * 2.0
		var travel_direction := (tangent + radial_correction).normalized()
		player.look_at(player.global_position + travel_direction, Vector3.UP)
		await physics_frame
		if player.global_position.y < start_position.y - 3.25:
			break
		if not player.is_on_floor():
			airborne_frames += 1
		if player.velocity.y < -0.1:
			falling_frames += 1
	Input.action_release("move_forward")

	print("Generated descent final player position: ", player.global_position)
	print("Generated descent airborne frames: ", airborne_frames)
	print("Generated descent falling frames: ", falling_frames)
	_check(player.global_position.y < start_position.y - 3.25,
		"normal forward movement descends the full tower stair flight")
	_check(airborne_frames <= 2, "player keeps floor contact while descending the stair ramp")
	_check(falling_frames <= 2, "player stays grounded while descending the stair ramp")

	scene.free()
	player = null
	if _fail == 0:
		print("STAIR DESCENT TEST OK")
	else:
		print("STAIR DESCENT TEST FAILURES: ", _fail)
	quit(_fail)
func _check(ok: bool, msg: String) -> void:
	if ok:
		print("[PASS] ", msg)
	else:
		_fail += 1
		push_error("[FAIL] " + msg)
