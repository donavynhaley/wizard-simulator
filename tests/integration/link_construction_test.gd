extends SceneTree

## End-to-end coverage for player-built links: the wizard holds a Bind rune,
## carries a thread from a fire fount to a patch of ground, and the LinkForge
## emergently produces a Warmth link that heats the ground - no per-object
## wiring. Then a Sever rune cuts the strand and the ground cools. Proves the
## extracted LinkAnchor / LinkEffect / LinkForge / MagicalLink system and the
## carry-the-thread construction gesture.

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var floor := _static_box(Vector3(40.0, 1.0, 40.0))
	root.add_child(floor)
	floor.global_position = Vector3(0.0, -0.5, 0.0)

	var player := (load("res://game/player/player.tscn") as PackedScene).instantiate() as WizardPlayer
	root.add_child(player)
	await process_frame
	await process_frame
	var camera := player.get_node(^"Head/Camera3D") as Camera3D
	var fire := load("res://game/spellcraft/elements/fire.tres") as Element

	# A fire fount: a lit ElementSource with a LinkAnchor that draws from it.
	var fount := Node3D.new()
	root.add_child(fount)
	fount.global_position = camera.global_position + camera.global_transform.basis \
		* Vector3(-1.4, 0.0, -3.0)
	var fire_source := ElementSource.new()
	fire_source.element = fire
	# one_shot so the test can siphon it away and back to exercise power changes.
	fire_source.one_shot = true
	fount.add_child(fire_source)
	var fount_anchor := LinkAnchor.new()
	fount_anchor.kind = &"fount"
	fount_anchor.source_path = NodePath("../" + str(fire_source.name))
	fount.add_child(fount_anchor)

	# A patch of ground: a HeatSink whose LinkAnchor accepts a warmth link.
	var ground := HeatSink.new()
	root.add_child(ground)
	ground.global_position = camera.global_position + camera.global_transform.basis \
		* Vector3(1.4, -0.4, -3.0)
	var ground_anchor := LinkAnchor.new()
	ground_anchor.kind = &"ground"
	ground.add_child(ground_anchor)
	await process_frame
	await process_frame

	var casting := player.casting
	var sight := player.sight
	player.look_enabled = false

	# The forge alone resolves the emergent effect from what is connected.
	_check(LinkForge.resolve(fount_anchor, ground_anchor) is HeatEffect,
		"fire fount + ground resolves to a Warmth effect")
	_check(LinkForge.resolve(fount_anchor, fount_anchor) == null,
		"an anchor cannot bind to itself")

	# Hold a Bind rune and raise Sight.
	casting.locked_rune_id = &"bind"
	casting.locked_rune_score = 1.0
	casting._set_state(CastingController.CASTING_STATE.SPELL_HELD)
	Input.action_press(&"sight")
	await process_frame
	await process_frame
	_check(sight.active, "Sight activates while a Bind waits in hand")

	# Aim at the fount and press: grab the thread.
	_aim_player_at(player, camera, fount_anchor.anchor_point())
	await process_frame
	await process_frame
	_check(sight.aimed_anchor() == fount_anchor, "Bind aims at the fire fount anchor")
	await _press_cast()
	_check(sight.is_carrying_thread(), "the first Bind press grabs a thread from the fount")

	# Aim at the ground and press: attach, forging the link.
	_aim_player_at(player, camera, ground_anchor.anchor_point())
	await process_frame
	await process_frame
	_check(sight.aimed_anchor() == ground_anchor, "Bind aims at the ground anchor")
	await _press_cast()
	await process_frame
	await process_frame

	var link := _first_link()
	_check(link != null, "attaching the thread forges a live magical link")
	_check(not sight.is_carrying_thread(), "forging ends the carry")
	_check(casting.current_state == CastingController.CASTING_STATE.IDLE,
		"forging consumes the held Bind rune")
	_check(ground.is_hot(), "the forged Warmth link heats the ground")

	# Starve the fount: the link cools its ground without being severed.
	fire_source.consume(fire_source.global_position + Vector3.UP * 0.5)
	await create_timer(0.8).timeout
	_check(not ground.is_hot(), "starving the fount cools the ground through the link")
	fire_source.restore(fire_source.global_position + Vector3.UP * 0.5)
	await create_timer(0.6).timeout
	_check(ground.is_hot(), "refeeding the fount reheats the ground")

	# Hold a Sever rune, aim at the strand, and cut it.
	casting.locked_rune_id = &"sever"
	casting.locked_rune_score = 1.0
	casting._set_state(CastingController.CASTING_STATE.SPELL_HELD)
	_aim_player_at(player, camera, link.gate_point())
	await process_frame
	await process_frame
	_check(sight.aimed_link() == link, "Sever aims at the forged strand")
	await _press_cast()
	await process_frame
	_check(casting.current_state == CastingController.CASTING_STATE.IDLE,
		"severing consumes the held Sever rune")
	await process_frame
	await process_frame
	_check(not ground.is_hot(), "severing the link cools the ground")
	_check(not is_instance_valid(link) or link.is_queued_for_deletion(),
		"severing frees the strand")

	Input.action_release(&"sight")
	player.queue_free()
	await process_frame
	if _fail == 0:
		print("LINK CONSTRUCTION TEST OK")
	quit(_fail)


func _first_link() -> MagicalLink:
	for node in root.get_tree().get_nodes_in_group(MagicalLink.GROUP):
		var link := node as MagicalLink
		if link != null and not link.is_queued_for_deletion():
			return link
	return null


func _aim_player_at(player: WizardPlayer, camera: Camera3D, point: Vector3) -> void:
	var flat_target := Vector3(point.x, player.global_position.y, point.z)
	if flat_target.distance_to(player.global_position) > 0.01:
		player.look_at(flat_target, Vector3.UP)
	var offset := point - camera.global_position
	player.head.rotation.x = atan2(offset.y, Vector2(offset.x, offset.z).length())


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


func _static_box(size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		push_error("[FAIL] %s" % message)
		_fail = 1
