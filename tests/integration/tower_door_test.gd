extends SceneTree

## End-to-end check of the entrance door mechanism in the real tower scene:
## authored animation, moving collision, prompts, blocking, and traversal.
## The arcane-lock ward itself is covered by door_lock_test; here the ward is
## fed first so the door behaves as a plain door for the whole cycle.

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := (load("res://game/world/levels/wizard_tower.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	# The ward wires itself and drains the lantern via deferred calls; feeding
	# before that settles would be silently undone by the authored drain.
	for _frame in 10:
		await physics_frame

	var player := scene.get_node_or_null(^"Player") as WizardPlayer
	var architecture := scene.get_node_or_null(^"TowerArchitecture") as TowerArchitecture
	var door := architecture.find_child("EntryDoor", true, false) if architecture else null
	_check(player != null, "tower door test composes the real player")
	_check(door != null, "tower entrance provides an interactive door controller")
	if player == null or door == null:
		_finish()
		return

	# Feed the ward so the door unlocks; the fed Bind auto-swings the door
	# open, so close it again to start the mechanical open/close cycle.
	var lantern_source := scene.get_node_or_null(
		^"TowerArchitecture/GroundFloorProps/DoorLantern/MagicalFlame/FireSource") as ElementSource
	_check(lantern_source != null, "the door lantern vessel exists to feed the ward")
	if lantern_source == null:
		_finish()
		return
	lantern_source.restore(lantern_source.global_position + Vector3.UP * 0.5)
	# The Bind drinks over the ash tween (~0.4s) before releasing the lock.
	await create_timer(0.9).timeout
	_check(bool(door.call("is_open")), "feeding the ward swings the door open")
	door.call("interact", player, door)
	for _frame in 100:
		await physics_frame
	_check(not bool(door.call("is_open")), "the unlocked door closes on interact")

	var animation_player := door.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	var collision_body := door as AnimatableBody3D
	# Positions derive from the closed door's collision shape, not literals:
	# the tower has already moved once (2026-07-21 scene split) and hardcoded
	# coordinates silently turned this suite stale.
	var slab := (door.get_node(^"CollisionShape3D") as CollisionShape3D).global_position
	var outside_spawn := Vector3(0.0, 1.05, slab.z + 1.8)
	_check(animation_player != null and animation_player.has_animation(&"open"),
		"tower door owns an authored opening animation")
	_check(collision_body != null, "tower door uses moving collision")
	_check(collision_body != null and collision_body.get_node_or_null(^"CollisionShape3D") != null,
		"door collision is part of the animated hinge body")
	_check(player.interactor._find_interactable(collision_body) == door,
		"the player's look-to-focus ray resolves the door interactable")
	_check(str(door.call("focus_prompt", player, collision_body)) == "Open tower door",
		"closed door prompts the player to open it")

	player.global_position = outside_spawn
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	for _frame in 5:
		await physics_frame
	Input.action_press(&"move_forward")
	for _frame in 100:
		await physics_frame
	Input.action_release(&"move_forward")
	print("Closed door approach position: ", player.global_position, " slab z: ", slab.z)
	_check(player.global_position.z >= slab.z + 0.3,
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

	player.global_position = outside_spawn
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
	_check(player.global_position.z < slab.z - 0.6,
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
