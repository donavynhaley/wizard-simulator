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

	# A fire orb on the left anchor, as the controller would spawn it.
	var anchor := arms.get_node_or_null("arms/Skeleton3D/LeftHandAttachment/SpellAnchor")
	var orb_scene := load("res://game/spellcraft/casting/effects/spell_palm_effect.tscn") as PackedScene
	var fire := load("res://game/spellcraft/elements/fire.tres") as Element
	if anchor != null and orb_scene != null:
		var orb := orb_scene.instantiate() as Node3D
		anchor.add_child(orb)
		orb.scale = Vector3.ONE * 0.7
		if fire != null:
			fire.apply_to(orb)

	await physics_frame
	for frame in 20:
		await process_frame

	var image := viewport.get_texture().get_image()
	var err := image.save_png(OUT)
	print("saved=", OUT, " err=", err, " size=", image.get_size())
	quit(err)
