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
	var stair_ramp := scene.find_child("central_spiral_stair_ramp", true, false)
	_check(stair_visual != null and stair_visual.find_child("StaticBody3D", true, false) == null,
		"visible tower steps do not use their risers as player collision")
	_check(stair_ramp != null and stair_ramp.find_child("CollisionShape3D", true, false) != null,
		"tower stairs provide a separate walkable ramp collision")
	if stair_visual == null:
		print("STAIR STEP TEST FAILURES: ", _fail)
		quit(maxi(_fail, 1))
		return

	# The tower no longer sits at the world origin (2026-07-21 scene split), so
	# derive the spiral axis from the stair mesh instead of hardcoding it.
	var stair_aabb := stair_visual.get_aabb()
	var spiral_center: Vector3 = stair_visual.global_transform * stair_aabb.get_center()
	var base_y := spiral_center.y - stair_aabb.size.y * 0.5

	# Follow the authored spiral with ordinary forward movement. The locomotion
	# component has no stair awareness; the ramp is simply a walkable floor.
	var start_angle := -0.1
	player.global_position = Vector3(
		spiral_center.x + cos(start_angle) * 1.25,
		base_y + 1.05,
		spiral_center.z - sin(start_angle) * 1.25)

	for index in 5:
		await physics_frame

	var start_position := player.global_position
	var highest_y := start_position.y
	Input.action_press("move_forward")
	for index in 300:
		var offset := Vector3(player.global_position.x - spiral_center.x, 0.0,
			player.global_position.z - spiral_center.z)
		var angle := atan2(-offset.z, offset.x)
		var tangent := Vector3(-sin(angle), 0.0, -cos(angle))
		var radial_correction := offset.normalized() * (1.25 - offset.length()) * 2.0
		var travel_direction := (tangent + radial_correction).normalized()
		player.look_at(player.global_position + travel_direction, Vector3.UP)
		await physics_frame
		highest_y = maxf(highest_y, player.global_position.y)
		if player.global_position.y > start_position.y + 3.25:
			break
	Input.action_release("move_forward")

	print("Start player position: ", start_position)
	print("Final player position: ", player.global_position)
	print("Highest player Y: ", highest_y)
	_check(highest_y > start_position.y + 3.25,
		"normal forward movement climbs the full tower stair flight")
	var final_radius := Vector2(player.global_position.x - spiral_center.x,
		player.global_position.z - spiral_center.z).length()
	_check(final_radius > 0.45 and final_radius < 2.15,
		"the walkable ramp follows the visible spiral staircase")

	await process_frame
	current_scene = null
	scene.queue_free()
	player = null
	scene = null
	await process_frame
	await process_frame

	if _fail == 0:
		print("STAIR STEP TEST OK")
	else:
		print("STAIR STEP TEST FAILURES: ", _fail)
	call_deferred("_finish")


func _finish() -> void:
	quit(_fail)

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("[PASS] ", msg)
	else:
		_fail += 1
		push_error("[FAIL] " + msg)
