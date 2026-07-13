extends SceneTree

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node3D.new()
	scene.name = "GeneratedStairDescent"
	root.add_child(scene)

	var player := (load("res://game/player/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	scene.add_child(player)

	var step_count := 8
	var step_height := 0.28
	var step_depth := 0.62
	for index in step_count:
		var top_y := float(step_count - index) * step_height
		_add_step(
			scene,
			Vector3(0.0, top_y - step_height * 0.5, -float(index) * step_depth),
			Vector3(2.4, step_height, step_depth))

	player.global_position = Vector3(0.0, float(step_count) * step_height + 0.9, 0.0)
	player.rotation = Vector3.ZERO
	for index in 5:
		await physics_frame

	var falling_frames := 0
	var airborne_frames := 0
	Input.action_press("move_forward")
	for index in 140:
		await physics_frame
		var over_stairs := player.global_position.z > -float(step_count - 1) * step_depth
		if not over_stairs:
			break
		if not player.is_on_floor():
			airborne_frames += 1
		if player.velocity.y < -0.1:
			falling_frames += 1
	Input.action_release("move_forward")

	print("Generated descent final player position: ", player.global_position)
	print("Generated descent airborne frames: ", airborne_frames)
	print("Generated descent falling frames: ", falling_frames)
	_check(player.global_position.z < -2.4, "player moves down generated stairs")
	_check(
		player.global_position.y < float(step_count) * step_height + 0.5,
		"player descends generated stairs")
	_check(airborne_frames <= 2, "player keeps floor contact while descending generated stairs")
	_check(falling_frames <= 2, "player stays grounded while descending generated stairs")

	scene.free()
	player = null
	if _fail == 0:
		print("STAIR DESCENT TEST OK")
	else:
		print("STAIR DESCENT TEST FAILURES: ", _fail)
	quit(_fail)


func _add_step(parent: Node3D, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position
	parent.add_child(body)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("[PASS] ", msg)
	else:
		_fail += 1
		push_error("[FAIL] " + msg)
