extends SceneTree

## End-to-end check of the entrance door in the real tower scene.
## The same interactable must animate its visual and moving collision open,
## then reverse that animation when the player interacts again.

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := (load("res://game/world/levels/wizard_tower.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	var player := scene.get_node_or_null(^"Player") as WizardPlayer
	var architecture := scene.get_node_or_null(^"TowerArchitecture") as TowerArchitecture
	var door := architecture.find_child("EntryDoor", true, false) if architecture else null
	_check(player != null, "tower door test composes the real player")
	_check(door != null, "tower entrance provides an interactive door controller")
	if player == null or door == null:
		_finish()
		return

	var animation_player := door.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	var collision_body := door as AnimatableBody3D
	_check(animation_player != null and animation_player.has_animation(&"open"),
		"tower door owns an authored opening animation")
	_check(collision_body != null, "tower door uses moving collision")
	_check(collision_body != null and collision_body.get_node_or_null(^"CollisionShape3D") != null,
		"door collision is part of the animated hinge body")
	_check(player.interactor._find_interactable(collision_body) == door,
		"the player's look-to-focus ray resolves the door interactable")
	_check(not bool(door.call("is_open")), "tower door starts closed")
	_check(str(door.call("focus_prompt", player, collision_body)) == "Open tower door",
		"closed door prompts the player to open it")

	player.global_position = Vector3(0.0, 1.05, 8.0)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	for _frame in 5:
		await physics_frame
	Input.action_press(&"move_forward")
	for _frame in 100:
		await physics_frame
	Input.action_release(&"move_forward")
	print("Closed door approach position: ", player.global_position)
	_check(player.global_position.z >= 6.25,
		"closed door collision blocks the player at the wooden slab")

	var closed_yaw := (door as Node3D).rotation.y
	door.call("interact", player, collision_body)
	_check(bool(door.call("is_open")), "interacting targets the open state")
	_check(str(door.call("focus_prompt", player, collision_body)) == "Close tower door",
		"opening immediately updates the interaction prompt")
	for _frame in 100:
		await physics_frame
	var open_yaw := (door as Node3D).rotation.y
	print("Door open progress/yaw: ", door.get("open_progress"), " / ", rad_to_deg(open_yaw))
	print("Door open collision transform: ", collision_body.global_transform)
	_check(absf(rad_to_deg(angle_difference(closed_yaw, open_yaw))) >= 95.0,
		"opening animation swings the door fully clear of the entrance")

	player.global_position = Vector3(0.0, 1.05, 8.0)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	for _frame in 5:
		await physics_frame
	Input.action_press(&"move_forward")
	for _frame in 100:
		await physics_frame
	Input.action_release(&"move_forward")
	print("Open door traversal position: ", player.global_position)
	_check(player.global_position.z < 5.5,
		"open door collision clears the entrance for the player")

	door.call("interact", player, collision_body)
	_check(not bool(door.call("is_open")), "interacting again targets the closed state")
	for _frame in 100:
		await physics_frame
	print("Door closed progress/yaw: ", door.get("open_progress"), " / ",
		rad_to_deg((door as Node3D).rotation.y))
	_check(is_equal_approx((door as Node3D).rotation.y, closed_yaw),
		"closing animation returns the door to its frame")
	_check(str(door.call("focus_prompt", player, collision_body)) == "Open tower door",
		"closed door restores the opening prompt")

	scene.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("TOWER DOOR TEST OK")
	else:
		print("TOWER DOOR TEST FAILURES: ", _failures)
	quit(_failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		_failures += 1
		push_error("[FAIL] " + message)
