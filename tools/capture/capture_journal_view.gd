extends SceneTree

# Captures the journal pause menu open in the spellcraft lab, for checking the
# book pose, page layout, and bookmark tabs from the CLI:
#   godot --path . -s tools/capture/capture_journal_view.gd          -> menu spread
#   godot --path . -s tools/capture/capture_journal_view.gd -- 1     -> spread index 1 (runes)
const OUT := "/tmp/journal_view.png"
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
	var journal := player.get_node_or_null("Components/JournalMenu") as JournalMenu
	await process_frame  # deferred book build
	if journal == null or journal._book == null:
		print("NO_JOURNAL")
		quit(1)
		return

	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	journal._unhandled_input(escape)

	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		journal._book.jump_to_spread(int(args[0]))
		journal._refresh_bookmarks()

	await physics_frame
	for frame in 110:
		await process_frame

	var image := viewport.get_texture().get_image()
	var err := image.save_png(OUT)
	print("saved=", OUT, " err=", err, " size=", image.get_size())
	quit(err)
