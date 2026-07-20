extends SceneTree

# Captures the player's first-person view in the spellcraft lab so the hat brim
# and arm placement can be checked from the CLI. Renders into a fixed-size
# SubViewport so tiling window managers cannot skew the aspect ratio.
# Optional user arg = head pitch in degrees (negative looks down):
#   godot --path . -s tools/capture/capture_first_person_view.gd -- -20
const OUT := "/tmp/first_person_view.png"
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

	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var head := player.get_node("Head") as Node3D
		head.rotation.x = deg_to_rad(float(args[0]))

	await physics_frame
	for frame in 6:
		await process_frame

	var image := viewport.get_texture().get_image()
	var err := image.save_png(OUT)
	print("saved=", OUT, " err=", err, " size=", image.get_size())
	quit(err)
