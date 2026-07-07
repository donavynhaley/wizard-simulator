extends SceneTree

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _run_tower_step_test()
	await _run_generated_descent_test()

	if _fail == 0:
		print("STAIR STEP TEST OK")
	else:
		print("STAIR STEP TEST FAILURES: ", _fail)
	quit(_fail)


func _run_tower_step_test() -> void:
	var scene := (load("res://scenes/levels/wizard_tower.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame

	var player := scene.get_node("Player") as CharacterBody3D
	player.global_position = Vector3(0.0, 0.9, 5.4)
	player.rotation = Vector3.ZERO

	for index in 5:
		await physics_frame

	var start_position := player.global_position
	var highest_y := start_position.y
	Input.action_press("move_forward")
	for index in 180:
		await physics_frame
		highest_y = maxf(highest_y, player.global_position.y)
	Input.action_release("move_forward")

	print("Start player position: ", start_position)
	print("Final player position: ", player.global_position)
	print("Highest player Y: ", highest_y)
	_check(highest_y > start_position.y + 0.35, "player gains height on tower steps")
	_check(player.global_position.z < start_position.z - 1.0, "player keeps moving toward the staircase")

	root.remove_child(scene)
	scene.queue_free()


func _run_generated_descent_test() -> void:
	var scene := Node3D.new()
	scene.name = "GeneratedStairDescent"
	root.add_child(scene)

	var player := (load("res://scenes/characters/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	scene.add_child(player)

	var step_count := 8
	var step_height := 0.28
	var step_depth := 0.62
	for index in step_count:
		var top_y := float(step_count - index) * step_height
		_add_step(scene, Vector3(0.0, top_y - step_height * 0.5, -float(index) * step_depth), Vector3(2.4, step_height, step_depth))

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
	_check(player.global_position.y < float(step_count) * step_height + 0.5, "player descends generated stairs")
	_check(airborne_frames <= 2, "player keeps floor contact while descending generated stairs")
	_check(falling_frames <= 2, "player stays grounded while descending generated stairs")

	root.remove_child(scene)
	scene.queue_free()


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
