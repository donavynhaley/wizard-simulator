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
	var start_angle := 0.1
	player.global_position = Vector3(
		cos(start_angle) * 1.25, 4.75, -sin(start_angle) * 1.25)
	for index in 30:
		await physics_frame
		if player.is_on_floor():
			break

	var start_position := player.global_position
	var falling_frames := 0
	var airborne_frames := 0
	Input.action_press("move_forward")
	for index in 300:
		var offset := Vector3(player.global_position.x, 0.0, player.global_position.z)
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
