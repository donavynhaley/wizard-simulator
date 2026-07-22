extends SceneTree

## Captures the real spellcraft-lab flow after grabbing fire and entering rune
## tracing, including both animation players, the held element, cursor, and ink.

const OUT := "/tmp/lab_element_tracing.png"


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
	var flat_target := Vector3(
		source.global_position.x, player.global_position.y, source.global_position.z)
	player.look_at(flat_target, Vector3.UP)
	var offset := source.siphon_point() - camera.global_position
	player.head.rotation.x = atan2(offset.y, Vector2(offset.x, offset.z).length())
	await process_frame

	_parse_key(KEY_Q, true)
	await process_frame
	_parse_mouse_button(MOUSE_BUTTON_LEFT, true)
	await process_frame
	_parse_mouse_button(MOUSE_BUTTON_LEFT, false)
	_parse_key(KEY_Q, false)
	for frame in 35:
		await process_frame
	print(
		"after_grab control=", player.control_enabled(),
		" process_input=", player.casting.is_processing_input(),
		" focus_held=", Input.is_action_pressed(&"cast_focus"),
		" mouse_mode=", Input.mouse_mode)

	_parse_mouse_button(MOUSE_BUTTON_RIGHT, true)
	await process_frame
	var debug_right_animation := camera.get_node(
		^"Viewmodel/WizardArms/AnimationPlayer") as AnimationPlayer
	print(
		"after_focus_press state=", player.casting.current_state,
		" focus_held=", Input.is_action_pressed(&"cast_focus"),
		" accumulator=", player.casting.sketching_state_time_accumulator,
		" right=", debug_right_animation.current_animation)
	await create_timer(player.casting.enable_sketching_state_time + 0.12).timeout
	print(
		"after_focus_hold state=", player.casting.current_state,
		" focus_held=", Input.is_action_pressed(&"cast_focus"),
		" accumulator=", player.casting.sketching_state_time_accumulator,
		" right=", debug_right_animation.current_animation)
	_parse_mouse_button(MOUSE_BUTTON_LEFT, true)
	for movement in [Vector2(55.0, -20.0), Vector2(45.0, 15.0), Vector2(35.0, -30.0)]:
		var motion := InputEventMouseMotion.new()
		motion.position = root.get_visible_rect().size * 0.5
		motion.relative = movement
		motion.screen_relative = movement
		Input.parse_input_event(motion)
		await process_frame
	for frame in 8:
		await process_frame

	var arms := camera.get_node(^"Viewmodel/WizardArms") as Node3D
	var right_animation := arms.get_node(^"AnimationPlayer") as AnimationPlayer
	var left_animation := arms.get_node(^"LeftAnimationPlayer") as AnimationPlayer
	print(
		"state=", player.casting.current_state,
		" sight=", player.sight.active,
		" element=", player.element_hand.held_element().id,
		" right=", right_animation.current_animation,
		" left=", left_animation.current_animation,
		" ribbon=", player.casting._ribbon.visible,
		" strokes=", player.casting._strokes.size())
	var image := root.get_texture().get_image()
	var error := image.save_png(OUT)
	print("saved=", OUT, " err=", error, " size=", image.get_size())
	_parse_mouse_button(MOUSE_BUTTON_LEFT, false)
	_parse_mouse_button(MOUSE_BUTTON_RIGHT, false)
	lab.queue_free()
	await process_frame
	await process_frame
	quit(error)


func _parse_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _parse_mouse_button(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = root.get_visible_rect().size * 0.5
	Input.parse_input_event(event)
