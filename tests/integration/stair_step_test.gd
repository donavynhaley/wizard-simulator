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
