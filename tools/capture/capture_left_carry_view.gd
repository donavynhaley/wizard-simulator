extends SceneTree

# Captures the first-person view with the LEFT arm posed in its mirrored carry
# hold (spell_carry_left) and a fire orb at the left wrist anchor, so the
# animation transfer can be checked from the CLI:
#   godot --path . -s tools/capture/capture_left_carry_view.gd
# Optional user arg = also play a right-hand clip name (e.g. spell_held) to
# check both arms together.
const OUT := "/tmp/left_carry_view.png"
const CAPTURE_SIZE := Vector2i(1280, 720)


func _init() -> void:
	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var scene := load("res://game/spellcraft/spellcraft_lab.tscn") as PackedScene
	var world := scene.instantiate()
	viewport.add_child(world)
	await process_frame
	await process_frame

	var player := world.get_node_or_null("Player")
	if player == null:
		print("NO_PLAYER")
		quit(1)
		return

	var arms := player.get_node_or_null("Head/Camera3D/Viewmodel/WizardArms")
	if arms == null:
		print("NO_LEFT_ANIMATION_PLAYER")
		quit(1)
		return
	var left_anim := arms.get_node_or_null("LeftAnimationPlayer") as AnimationPlayer
	if left_anim == null:
		print("NO_LEFT_ANIMATION_PLAYER")
		quit(1)
		return
	left_anim.play(&"spell_carry_left")

	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var right_anim := arms.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if right_anim != null and right_anim.has_animation(StringName(args[0])):
			right_anim.play(StringName(args[0]))

	# The carried fire on the left anchor, exactly as the controller spawns it -
	# its bespoke held_scene (the shared MagicalFlame) at the element's held_scale,
	# kept upright, with the forward torch spotlight on the camera.
	var anchor := arms.get_node_or_null("arms/Skeleton3D/LeftHandAttachment/SpellAnchor")
	var fire := load("res://game/spellcraft/elements/fire.tres") as Element
	var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
	var held: Node3D = null
	if anchor != null and fire != null and fire.held_scene != null:
		held = fire.held_scene.instantiate() as Node3D
		anchor.add_child(held)
		held.scale = Vector3.ONE * fire.held_scale
		fire.apply_to(held)
		if held.has_method(&"set_light_scale"):
			held.call(&"set_light_scale", 0.4, 0.9)
		if held.has_method(&"set_particles_emitting"):
			held.call(&"set_particles_emitting", false)
		if fire.held_torch and camera != null:
			var torch := SpotLight3D.new()
			camera.add_child(torch)
			torch.position = Vector3(0.0, -0.12, -0.25)
			torch.light_color = Color(1.0, 0.62, 0.34)
			torch.light_energy = 4.0
			torch.spot_range = 14.0
			torch.spot_angle = 36.0

	await physics_frame
	for frame in 20:
		# Keep the flame upright every frame, as the controller does, since the
		# carry animation keeps re-rotating the wrist bone under it.
		if held != null:
			held.global_rotation = Vector3.ZERO
		await process_frame

	var image := viewport.get_texture().get_image()
	var err := image.save_png(OUT)
	print("saved=", OUT, " err=", err, " size=", image.get_size())
	quit(err)
