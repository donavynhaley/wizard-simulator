extends SceneTree

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := (load("res://game/player/player.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	_check(scene is WizardPlayer, "player scene compiles as a WizardPlayer")
	if scene is not WizardPlayer:
		scene.queue_free()
		quit(_fail)
		return

	var player := scene as WizardPlayer
	var before_yaw := player.rotation.y
	var head := player.get_node("Head") as Node3D
	var before_pitch := head.rotation.x

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._input(click)

	player.apply_mouse_look(Vector2(80.0, -35.0))

	_check(absf(player.rotation.y - before_yaw) > 0.001,
		"mouse look still yaws after left button is held")
	_check(absf(head.rotation.x - before_pitch) > 0.001,
		"mouse look still pitches after left button is held")

	scene.queue_free()
	await process_frame
	await process_frame

	if _fail == 0:
		print("PLAYER INPUT TEST OK")
	else:
		print("PLAYER INPUT TEST FAILURES: ", _fail)
	quit(_fail)


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("[PASS] ", msg)
	else:
		_fail += 1
		push_error("[FAIL] " + msg)
