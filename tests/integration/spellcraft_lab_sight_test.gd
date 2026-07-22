extends SceneTree

## Reproduces elemental gathering through the actual spellcraft lab, camera,
## source placement, HUD, and physical input events.

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab := (load(
		"res://game/spellcraft/spellcraft_lab.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	current_scene = lab
	await process_frame
	await physics_frame

	var player := lab.get_node(^"Player") as WizardPlayer
	var source := lab.get_node(^"Props/MagicalFlame/FireSource") as ElementSource
	var camera := player.get_node(^"Head/Camera3D") as Camera3D
	_aim_player_at(player, camera, source.siphon_point())
	# A real graphical window can emit recenter motion while capturing the mouse.
	# Freeze look only for the harness so the authored target stays under aim.
	player.look_enabled = false
	await process_frame
	await process_frame

	_send_key(KEY_Q, true)
	_send_mouse_button(MOUSE_BUTTON_LEFT, true)
	await process_frame
	_check(player.sight.active, "physical Q activates Wizard Sight in the spellcraft lab")
	_check(player.sight.aimed_source() == source,
		"the lab's fire source becomes the aimed Sight target")
	# Gathering is a held gesture: the element strains toward the palm for
	# pull_time before it rips free. A bare click must not be enough.
	_check(player.element_hand.held_element() == null,
		"a bare click does not gather - the pull must be held")
	await create_timer(player.sight.pull_time + 0.15).timeout
	_send_mouse_button(MOUSE_BUTTON_LEFT, false)
	await process_frame
	_check(player.element_hand.held_element() == source.element,
		"holding the pull gathers the lab's fire into the left hand")
	_check(not source.available(), "the gathered lab fire source becomes empty")
	var blocking_layer := CanvasLayer.new()
	lab.add_child(blocking_layer)
	var blocking_control := ColorRect.new()
	blocking_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocking_control.mouse_filter = Control.MOUSE_FILTER_STOP
	blocking_layer.add_child(blocking_control)
	await process_frame

	# Sight owns the hands until Q is released, even if a GUI control covers the
	# viewport. Right click cannot silently switch modes while Q remains held.
	_send_mouse_button(MOUSE_BUTTON_RIGHT, true)
	await process_frame
	var right_arm := camera.get_node(
		^"Viewmodel/WizardArms/AnimationPlayer") as AnimationPlayer
	_check(player.sight.active, "right click cannot interrupt active Wizard Sight")
	_check(right_arm.current_animation != &"cast_focus",
		"blocked right click does not raise the casting hand")
	await create_timer(player.casting.enable_sketching_state_time + 0.1).timeout
	_check(player.casting.current_state == CastingController.CASTING_STATE.IDLE,
		"holding blocked right click cannot enter rune tracing")

	_send_mouse_button(MOUSE_BUTTON_RIGHT, false)
	_send_key(KEY_Q, false)
	await process_frame

	# Once Sight is lowered, right click starts casting. Q is blocked throughout
	# the charge and active trace instead of stealing the sketching hand.
	_send_mouse_button(MOUSE_BUTTON_RIGHT, true)
	# Keep the accepted hold deterministic after its physical edge exercises input
	# routing. Graphical window systems can report an unrelated OS button release.
	Input.action_press(&"cast_focus")
	await process_frame
	_check(not player.sight.active, "right click starts casting after Wizard Sight is lowered")
	_check(right_arm.current_animation == &"cast_focus",
		"accepted right click raises the casting hand")
	_send_key(KEY_Q, true)
	await process_frame
	_check(not player.sight.active, "Q cannot interrupt the right-click casting charge")
	_send_key(KEY_Q, false)
	await create_timer(player.casting.enable_sketching_state_time + 0.1).timeout
	_check(player.casting.current_state == CastingController.CASTING_STATE.SKETCHING,
		"holding accepted right click enters rune tracing in the spellcraft lab")
	_send_key(KEY_Q, true)
	await process_frame
	_check(not player.sight.active, "Q cannot interrupt active rune tracing")
	_send_key(KEY_Q, false)
	await process_frame

	_send_mouse_button(MOUSE_BUTTON_LEFT, true)
	await process_frame
	var stroke_motion := InputEventMouseMotion.new()
	stroke_motion.position = root.get_visible_rect().size * 0.5
	stroke_motion.relative = Vector2(90.0, -45.0)
	Input.parse_input_event(stroke_motion)
	await process_frame
	_send_mouse_button(MOUSE_BUTTON_LEFT, false)
	await process_frame
	_check(not player.casting._strokes.is_empty()
		and player.casting._strokes[0].points.size() >= 2,
		"left click and mouse motion trace rune ink while right click is held")
	_check(player.casting.locked_rune_id == &"",
		"a lone diagonal shaft does not ignite Hurl in the live lab")

	_send_mouse_button(MOUSE_BUTTON_RIGHT, false)
	Input.action_release(&"cast_focus")
	await process_frame

	# Once the sketch is complete, the resulting held rune no longer blocks
	# Wizard Sight. This uses the physical Q mapping in the authored lab scene.
	player.casting.locked_rune_id = &"hurl"
	player.casting.locked_rune_score = 1.0
	player.casting._set_state(CastingController.CASTING_STATE.SPELL_HELD)
	_send_key(KEY_Q, true)
	await process_frame
	_check(player.sight.active, "physical Q activates Sight while a rune is held")
	_check(player.casting.current_state == CastingController.CASTING_STATE.SPELL_HELD,
		"physical Q preserves the held rune")
	_send_key(KEY_Q, false)
	await process_frame
	lab.queue_free()
	await process_frame
	if _fail == 0:
		print("SPELLCRAFT LAB SIGHT TEST OK")
	quit(_fail)


func _aim_player_at(player: WizardPlayer, camera: Camera3D, point: Vector3) -> void:
	var flat_target := Vector3(point.x, player.global_position.y, point.z)
	player.look_at(flat_target, Vector3.UP)
	var offset := point - camera.global_position
	player.head.rotation.x = atan2(offset.y, Vector2(offset.x, offset.z).length())


## Every synthetic edge uses a fresh event instance, matching separate physical
## transitions and avoiding platform-specific event reuse in graphical runs.
func _send_mouse_button(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = root.get_visible_rect().size * 0.5
	Input.parse_input_event(event)


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
func _check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		push_error("[FAIL] %s" % message)
		_fail = 1
