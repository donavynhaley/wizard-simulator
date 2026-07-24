extends SceneTree

## Regression: severing the aimed link, then aiming Sight at another target must
## not leave a freed reference in the SightController. The severed strand's
## MagicalLink is queue_free'd while _aimed still points at it; the next marker
## pass used to do `_aimed as MagicalLink`, which throws "Trying to cast a freed
## object" every frame (and never re-aims). Player-reported via the door ward:
## sever the ward, then look at the lantern above the door.
##
## The crash only surfaces with a rendering context (headless frees on a
## different beat), so the assertion carries the check: after looking at the
## lantern, Sight must have re-aimed onto it - impossible if the cast threw.

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := (load(
		"res://game/world/levels/wizard_tower.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(level)
	current_scene = level
	await process_frame
	for _frame in 10:
		await physics_frame

	var player := level.get_node(^"Player") as WizardPlayer
	var ward := level.get_node(^"TowerArchitecture/DoorWard") as MagicalLink
	var lantern_source := level.get_node(
		^"TowerArchitecture/GroundFloorProps/DoorLantern/MagicalFlame/FireSource") as ElementSource
	var sight := player.sight
	var casting := player.casting
	_check(ward != null and sight != null and casting != null and lantern_source != null,
		"the tower wires the ward, lantern, Sight, and casting")

	# Deterministic core (survives headless, where the free lands on a different
	# beat): a freed node left in _aimed must not crash the retarget onto a NEW
	# target. Without the guard, `_aimed as MagicalLink` throws before the
	# reassignment runs, so _aimed never advances to the new target. (A null
	# target can't show this - a freed object compares equal to null, so the
	# early-out swallows it; the crash needs a real new target under the aim.)
	var orphan := MagicalLink.new()
	var probe := Node3D.new()
	root.add_child(probe)
	sight._aimed = orphan
	orphan.free()
	sight._set_aimed_target(probe)
	_check(sight._aimed == probe,
		"retargeting past a freed aimed node reaches the new target instead of throwing")
	sight._aimed = null
	probe.free()

	# Stand outside, settle on the floor, and aim at the ward strand.
	player.look_enabled = false
	player.global_position = Vector3(0.0, 1.7, 9.2)
	player.velocity = Vector3.ZERO
	for _frame in 60:
		await physics_frame
		if player.is_on_floor() and player.velocity.length() < 0.05:
			break
	_aim_player_at(player, ward.gate_point())
	await process_frame

	# Activate Sight and prime a held Sever verb (the real reshaped-click path).
	Input.action_press(&"sight")
	await process_frame
	casting.locked_rune_id = &"sever"
	casting.locked_rune_score = 1.0
	casting._set_state(CastingController.CASTING_STATE.SPELL_HELD)
	await process_frame
	sight._update_markers()
	_check(sight.aimed_link() == ward, "the ward strand is the aimed Sight target")

	# Sever it, then aim Sight at the lantern above the door and hold Sight up.
	await _press_cast()
	await process_frame
	_check(not is_instance_valid(ward), "the sever tears the ward strand down")

	_aim_player_at(player, lantern_source.siphon_point())
	for _frame in 30:
		await physics_frame
		sight._update_markers()

	# With the bug, _aimed stays the freed ward and the cast throws before it can
	# re-aim, so Sight never lands on the lantern.
	_check(sight.aimed_source() == lantern_source,
		"Sight re-aims onto the lantern after the ward is severed")

	Input.action_release(&"sight")
	await process_frame
	level.queue_free()
	await process_frame
	if _fail == 0:
		print("SEVER LINK SIGHT TEST OK")
	quit(_fail)


func _aim_player_at(player: WizardPlayer, point: Vector3) -> void:
	var camera := player.get_node(^"Head/Camera3D") as Camera3D
	var flat_target := Vector3(point.x, player.global_position.y, point.z)
	if flat_target.distance_to(player.global_position) > 0.01:
		player.look_at(flat_target, Vector3.UP)
	var offset := point - camera.global_position
	player.head.rotation.x = atan2(offset.y, Vector2(offset.x, offset.z).length())


## A single cast click - the sever strike input.
func _press_cast() -> void:
	var press := InputEventAction.new()
	press.action = &"cast"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventAction.new()
	release.action = &"cast"
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		push_error("[FAIL] %s" % message)
		_fail = 1
