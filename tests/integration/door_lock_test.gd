extends SceneTree

## End-to-end coverage for the door ward binding (Case Minus One mechanics):
## the STARVED Bind holds the door sealed behind a cold lantern, the strand is
## read through the resonance attunement minigame (strikes timed to the read
## pulse), the learned text rises as a world inscription (not a toast), and
## feeding the lantern fire swings the door open while re-siphoning re-seals.

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
	var architecture := level.get_node(^"TowerArchitecture") as TowerArchitecture
	var door := architecture.entry_door
	var ward := level.get_node(^"TowerArchitecture/DoorWard") as MagicalLink
	var lantern_source := level.get_node(
		^"TowerArchitecture/GroundFloorProps/DoorLantern/MagicalFlame/FireSource") as ElementSource
	var torch_source := level.get_node_or_null(
		^"TowerArchitecture/ApproachTorch/MagicalFlame/FireSource") as ElementSource

	_check(ward != null, "the tower authors a door ward binding")
	_check(lantern_source != null, "the door lantern carries the ward's vessel")
	_check(not lantern_source.available(), "the lantern begins as an empty vessel")
	_check(not ward.is_powered(), "the Bind starts starved")
	_check(door.is_locked(), "the starved Bind holds the door sealed")
	_check(torch_source != null and torch_source.available(),
		"Maren's path torch still burns as the arrival fire source")

	door.interact(player, door)
	await process_frame
	_check(not door.is_open(), "the Bind refuses the door while starved")
	_check(door.focus_prompt(player, door) == "The door is locked by arcane magic",
		"the focus prompt names the ward")

	# Stand outside, land, and aim Sight at the strand's midpoint.
	player.look_enabled = false
	player.global_position = Vector3(0.0, 1.7, 9.2)
	player.velocity = Vector3.ZERO
	for _frame in 60:
		await physics_frame
		if player.is_on_floor() and player.velocity.length() < 0.05:
			break
	_aim_player_at(player, ward.gate_point())
	await process_frame
	Input.action_press(&"sight")
	await process_frame
	await process_frame
	_check(player.sight.active, "Sight activates outside the tower door")
	_check(player.sight.aimed_link() == ward,
		"the ward strand becomes the aimed Sight target")
	_check(not JournalFacts.knows(&"door_ward_source"), "the ward fact starts unlearned")

	# First cast press begins the attunement; the read-pulse starts travelling.
	await _press_cast()
	_check(ward.is_attuning(), "the first press begins the resonance attunement")

	# A deliberate off-window strike misses and resets the streak.
	var guard := 0
	while ward.is_phase_in_window() and guard < 600:
		guard += 1
		await process_frame
	await _press_cast()
	_check(ward.is_attuning() and ward.attunement_progress() == 0.0,
		"an off-window strike misses without ending the attunement")

	# Strike cleanly on each window pass until the working yields.
	guard = 0
	while not ward.is_analyzed() and guard < 3000:
		guard += 1
		await process_frame
		if ward.is_attuning() and ward.is_phase_in_window():
			await _press_cast()
	_check(JournalFacts.knows(&"door_ward_source"),
		"timed strikes through the resonance window ink door_ward_source")
	_check(not ward.is_attuning(), "a completed reading ends the attunement")

	# The learned text rises beside the strand as a world inscription.
	var inscription: Label3D = null
	for child in ward.get_children():
		if child is Label3D:
			inscription = child
	_check(inscription != null, "the ward carries a world inscription label")
	await process_frame
	_check(inscription != null and inscription.visible,
		"the inscription materialises in the world after the reading")
	# The text inks in character by character; wait for the full line.
	await create_timer(1.4).timeout
	_check(inscription != null and inscription.text == ward.inscription_text(),
		"the inscription carries the journal text")
	Input.action_release(&"sight")
	await process_frame

	# Feed the ward: fire into the lantern, the Bind drinks, the door opens.
	lantern_source.restore(lantern_source.global_position + Vector3.UP * 0.5)
	_check(ward.is_powered(), "fire placed in the lantern feeds the Bind")
	await create_timer(0.9).timeout
	_check(not door.is_locked(), "the fed Bind releases the door")
	_check(door.is_open(), "feeding the ward swings the door open")

	# Taking the fire back re-seals the tower - the consequence rule. The flame
	# is sucked toward the caster's hand, far from the lantern; the strand must
	# stay on the vessel, not ride the departing visual toward the hand.
	var lantern_anchor := ward.endpoint_a()
	var hand_point := player.global_position + Vector3(0.0, 1.4, -0.5)
	lantern_source.consume(hand_point)
	await process_frame
	await process_frame
	_check(ward.endpoint_a().distance_to(lantern_anchor) < 0.1,
		"siphoning the flame leaves the strand on the lantern, not the hand")
	await create_timer(0.9).timeout
	_check(ward.endpoint_a().distance_to(lantern_anchor) < 0.1,
		"the emptied strand stays anchored to the lantern")
	_check(not ward.is_powered(), "siphoning the lantern starves the Bind again")
	_check(door.is_locked(), "the starved Bind holds the Seal once more")
	_check(door.is_open(), "re-sealing does not slam the already-open door")

	level.queue_free()
	await process_frame
	if _fail == 0:
		print("DOOR WARD TEST OK")
	quit(_fail)


func _aim_player_at(player: WizardPlayer, point: Vector3) -> void:
	var camera := player.get_node(^"Head/Camera3D") as Camera3D
	var flat_target := Vector3(point.x, player.global_position.y, point.z)
	if flat_target.distance_to(player.global_position) > 0.01:
		player.look_at(flat_target, Vector3.UP)
	var offset := point - camera.global_position
	player.head.rotation.x = atan2(offset.y, Vector2(offset.x, offset.z).length())


## A single cast click - the attunement strike input.
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
