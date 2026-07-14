extends SceneTree

const PLAYER_SCENE := preload("res://game/player/player.tscn")

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_release_movement_actions()
	await _test_directional_acceleration()
	await _test_analog_input_strength()
	await _test_air_control()
	await _test_jump_height_control()
	await _test_direct_jump_without_grace_windows()
	await _test_coyote_jump()
	await _test_buffered_jump()
	await _test_tall_obstacle_rejection()
	await _test_blocked_viewmodel_motion()
	await _test_control_takeover_reset()
	_release_movement_actions()

	if _fail == 0:
		print("PLAYER MOVEMENT TEST OK")
	else:
		print("PLAYER MOVEMENT TEST FAILURES: ", _fail)
	quit(_fail)


func _test_directional_acceleration() -> void:
	var world := _make_world()
	var cardinal := await _spawn_player(world, Vector3(-3.0, 0.9, 0.0))
	Input.action_press("move_forward")
	await _physics_frames(6)
	var cardinal_speed := _horizontal_speed(cardinal)
	Input.action_release("move_forward")
	cardinal.queue_free()
	await process_frame

	var diagonal := await _spawn_player(world, Vector3(3.0, 0.9, 0.0))
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await _physics_frames(6)
	var diagonal_speed := _horizontal_speed(diagonal)
	Input.action_release("move_forward")
	Input.action_release("move_right")
	_check(absf(cardinal_speed - diagonal_speed) < 0.05,
		"cardinal and diagonal acceleration match (cardinal=%.2f, diagonal=%.2f)" \
		% [cardinal_speed, diagonal_speed])
	await _dispose_world(world)


func _test_analog_input_strength() -> void:
	var world := _make_world()
	var player := await _spawn_player(world, Vector3.ZERO + Vector3.UP * 0.9)
	Input.action_press("move_forward", 0.75)
	await _physics_frames(90)
	var analog_speed := _horizontal_speed(player)
	Input.action_release("move_forward")
	_check(analog_speed > 0.5 and analog_speed < player.locomotion.move_speed * 0.8,
		"partial analog input produces partial speed (speed=%.2f)" % analog_speed)
	await _dispose_world(world)


func _test_air_control() -> void:
	var world := _make_world()
	var grounded := await _spawn_player(world, Vector3(-3.0, 0.9, 0.0))
	Input.action_press("move_forward")
	await _physics_frames(4)
	var grounded_speed := _horizontal_speed(grounded)
	Input.action_release("move_forward")
	grounded.queue_free()
	await process_frame

	var airborne := await _spawn_player(world, Vector3(3.0, 5.0, 0.0), false)
	Input.action_press("move_forward")
	await _physics_frames(4)
	var airborne_speed := _horizontal_speed(airborne)
	Input.action_release("move_forward")
	_check(airborne_speed < grounded_speed * 0.6,
		"air control accelerates more slowly than grounded movement (ground=%.2f, air=%.2f)" \
		% [grounded_speed, airborne_speed])
	await _dispose_world(world)


func _test_jump_height_control() -> void:
	var world := _make_world()
	var tapped_height := await _measure_jump_height(world, 1)
	var held_height := await _measure_jump_height(world, 999)
	_check(held_height > tapped_height + 0.35,
		"releasing jump early produces a shorter jump (tap=%.2f, hold=%.2f)" \
		% [tapped_height, held_height])
	await _dispose_world(world)


func _test_direct_jump_without_grace_windows() -> void:
	var world := _make_world()
	var player := await _spawn_player(world, Vector3.ZERO + Vector3.UP * 0.9)
	player.locomotion.coyote_time = 0.0
	player.locomotion.jump_buffer_time = 0.0
	Input.action_press("jump")
	await _physics_frames(2)
	Input.action_release("jump")
	_check(player.velocity.y > 1.0,
		"zero grace-window settings still allow a direct grounded jump")
	await _dispose_world(world)


func _test_coyote_jump() -> void:
	var world := _make_world(false)
	var platform := _add_box(world, Vector3(0.0, -0.1, 0.0), Vector3(3.0, 0.2, 2.0))
	var player := await _spawn_player(world, Vector3(0.0, 0.9, 0.0))
	player.floor_snap_length = 0.0
	platform.queue_free()
	await physics_frame
	await physics_frame
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	_check(not player.is_on_floor() and player.velocity.y > 1.0,
		"jump remains available briefly after leaving floor contact (vy=%.2f)" \
		% player.velocity.y)
	await _dispose_world(world)


func _test_buffered_jump() -> void:
	var world := _make_world()
	var player := await _spawn_player(world, Vector3(0.0, 2.0, 0.0), false)
	player.floor_snap_length = 0.0
	while player.global_position.y > 1.2:
		await physics_frame
	Input.action_press("jump")
	var buffered_jump_fired := false
	for frame in 20:
		await physics_frame
		if player.velocity.y > 1.0:
			buffered_jump_fired = true
			break
	Input.action_release("jump")
	_check(buffered_jump_fired, "jump input shortly before landing is buffered")
	await _dispose_world(world)


func _test_tall_obstacle_rejection() -> void:
	var world := _make_world()
	_add_box(world, Vector3(0.0, 0.3, -0.5), Vector3(2.0, 0.6, 0.6))
	var player := await _spawn_player(world, Vector3(0.0, 0.9, 0.8))
	player.locomotion.enable_stair_stepping = true
	Input.action_press("move_forward")
	await _physics_frames(90)
	Input.action_release("move_forward")
	_check(player.global_position.y < 1.05 and player.global_position.z > 0.0,
		"automatic stair stepping rejects a 0.6 m obstacle")
	await _dispose_world(world)


func _test_blocked_viewmodel_motion() -> void:
	var world := _make_world()
	_add_box(world, Vector3(0.0, 1.5, -0.6), Vector3(3.0, 3.0, 0.2))
	var player := await _spawn_player(world, Vector3(0.0, 0.9, 0.2))
	player.locomotion.enable_stair_stepping = false
	Input.action_press("move_forward")
	await _physics_frames(45)
	var lowest_viewmodel_y := INF
	var highest_viewmodel_y := -INF
	for frame in 45:
		await physics_frame
		lowest_viewmodel_y = minf(lowest_viewmodel_y, player.viewmodel.position.y)
		highest_viewmodel_y = maxf(highest_viewmodel_y, player.viewmodel.position.y)
	Input.action_release("move_forward")
	var blocked_motion := highest_viewmodel_y - lowest_viewmodel_y
	_check(blocked_motion < 0.003,
		"viewmodel does not walk-bob while movement is blocked (range=%.4f m)" \
		% blocked_motion)
	await _dispose_world(world)


func _test_control_takeover_reset() -> void:
	var world := _make_world()
	var player := await _spawn_player(world, Vector3.ZERO + Vector3.UP * 0.9)
	player.velocity = Vector3(2.0, 1.0, -3.0)
	player.set_control_enabled(false)
	_check(player.velocity.is_zero_approx() and not player.is_physics_processing(),
		"disabling control clears movement momentum")
	player.set_control_enabled(true)
	_check(player.is_physics_processing(), "re-enabling control restores physics processing")
	await _dispose_world(world)


func _measure_jump_height(world: Node3D, release_after_frames: int) -> float:
	var player := await _spawn_player(world, Vector3.ZERO + Vector3.UP * 0.9)
	var start_height := player.global_position.y
	var peak_height := start_height
	Input.action_press("jump")
	for frame in 180:
		await physics_frame
		peak_height = maxf(peak_height, player.global_position.y)
		if frame == release_after_frames:
			Input.action_release("jump")
		if frame > 10 and player.is_on_floor():
			break
	Input.action_release("jump")
	player.queue_free()
	await process_frame
	await physics_frame
	return peak_height - start_height


func _make_world(with_floor: bool = true) -> Node3D:
	var world := Node3D.new()
	root.add_child(world)
	if with_floor:
		_add_box(world, Vector3(0.0, -0.1, 0.0), Vector3(20.0, 0.2, 20.0))
	return world


func _spawn_player(
		world: Node3D, position: Vector3, settle_on_floor: bool = true) -> WizardPlayer:
	var player := PLAYER_SCENE.instantiate() as WizardPlayer
	world.add_child(player)
	player.global_position = position
	player.locomotion.enable_stair_stepping = false
	await _physics_frames(5 if settle_on_floor else 1)
	return player


func _add_box(parent: Node3D, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _dispose_world(world: Node3D) -> void:
	_release_movement_actions()
	world.queue_free()
	await process_frame
	await physics_frame


func _physics_frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _horizontal_speed(player: CharacterBody3D) -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func _release_movement_actions() -> void:
	for action in ["move_forward", "move_backward", "move_left", "move_right", "jump"]:
		Input.action_release(action)


func _check(ok: bool, message: String) -> void:
	if ok:
		print("[PASS] ", message)
	else:
		_fail += 1
		push_error("[FAIL] " + message)
