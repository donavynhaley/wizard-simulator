extends SceneTree

# Captures the journal pause menu open in the spellcraft lab, for checking the
# book pose, page layout, and bookmark tabs from the CLI:
#   godot --path . -s tools/capture/capture_journal_view.gd          -> menu spread
#   godot --path . -s tools/capture/capture_journal_view.gd -- 1     -> spread index 1 (runes)
#   godot --path . -s tools/capture/capture_journal_view.gd -- focus -> close focus pose
#   godot --path . -s tools/capture/capture_journal_view.gd -- pull  -> mid-summon frame
#   godot --path . -s tools/capture/capture_journal_view.gd -- belt  -> journal at left hip
#   godot --path . -s tools/capture/capture_journal_view.gd -- dark  -> final pose without lighting
#   godot --path . -s tools/capture/capture_journal_view.gd -- profile -> angled cover/profile check
#   godot --path . -s tools/capture/capture_journal_view.gd -- profile 3 -> profile at spread 3
#   godot --path . -s tools/capture/capture_journal_view.gd -- turn  -> mid-page-turn frame
#   godot --path . --write-movie /tmp/journal_turn.avi -s \
#     tools/capture/capture_journal_view.gd -- turn-sequence         -> full turn recording
#   godot --path . --write-movie /tmp/journal_reverse.avi -s \
#     tools/capture/capture_journal_view.gd -- reverse-turn-sequence -> full back turn
const OUT := "/tmp/journal_view.png"
const CAPTURE_SIZE := Vector2i(1280, 720)


func _init() -> void:
	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	# Mirror the offscreen capture into the root window so Godot's --write-movie
	# recorder sees the same image that save_png() reads from the SubViewport.
	var movie_preview := TextureRect.new()
	movie_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	movie_preview.texture = viewport.get_texture()
	movie_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	movie_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	movie_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(movie_preview)

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

	var args := OS.get_cmdline_user_args()
	var capture_belt := not args.is_empty() and args[0] == "belt"
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	if not capture_belt:
		journal._unhandled_input(escape)
	else:
		var camera := player.get_node("Head/Camera3D") as Camera3D
		camera.rotation.x = deg_to_rad(-68.0)

	var capture_frames := 110
	var capture_pull := false
	var capture_page_turn := false
	var capture_page_turn_sequence := false
	var capture_reverse_turn_sequence := false
	var capture_profile := false
	if not args.is_empty() and args[0] == "focus":
		var focus := InputEventAction.new()
		focus.action = &"book_focus"
		focus.pressed = true
		journal._book._input(focus)
	elif not args.is_empty() and args[0] == "pull":
		capture_pull = true
		capture_frames = 0
	elif capture_belt:
		capture_frames = 20
	elif not args.is_empty() and args[0] == "dark":
		for node in world.find_children("*", "Light3D", true, false):
			(node as Light3D).visible = false
		var world_environment := world.find_child(
			"WorldEnvironment", true, false) as WorldEnvironment
		if world_environment != null and world_environment.environment != null:
			world_environment.environment = world_environment.environment.duplicate(true)
			world_environment.environment.background_mode = Environment.BG_COLOR
			world_environment.environment.background_color = Color.BLACK
			world_environment.environment.ambient_light_energy = 0.0
	elif not args.is_empty() and args[0] == "profile":
		capture_profile = true
		capture_frames = 4
		if args.size() > 1:
			journal._book.jump_to_spread(int(args[1]))
			journal._refresh_bookmarks()
		if journal._summon_animation != null:
			journal._summon_animation.seek(
				journal._summon_animation.current_animation_length, true)
	elif not args.is_empty() and args[0] == "turn":
		capture_page_turn = true
	elif not args.is_empty() and args[0] == "turn-sequence":
		capture_page_turn_sequence = true
		capture_frames = 4
		if journal._summon_animation != null:
			journal._summon_animation.seek(
				journal._summon_animation.current_animation_length, true)
	elif not args.is_empty() and args[0] == "reverse-turn-sequence":
		capture_reverse_turn_sequence = true
		capture_frames = 4
		if journal._summon_animation != null:
			journal._summon_animation.seek(
				journal._summon_animation.current_animation_length, true)
		journal._book.jump_to_spread(1)
		journal._refresh_bookmarks()
	elif not args.is_empty():
		journal._book.jump_to_spread(int(args[0]))
		journal._refresh_bookmarks()

	await physics_frame
	for frame in capture_frames:
		await process_frame
	if capture_pull:
		for frame in 300:
			if journal.summon_progress >= 0.4:
				break
			await process_frame
	elif not capture_belt and not capture_profile \
			and not capture_page_turn_sequence \
			and not capture_reverse_turn_sequence:
		for frame in 360:
			if not journal.is_transitioning():
				break
			await process_frame
	if capture_profile and journal._summon_mount != null:
		journal._summon_mount.rotate_y(deg_to_rad(-28.0))
		journal._summon_mount.rotate_x(deg_to_rad(12.0))
		for frame in 3:
			await process_frame
	if capture_page_turn:
		journal._book.turn_to_spread(1)
		var visual := journal._book.get_node("Visual") as BookVisual
		for frame in 10:
			if visual._turn_tween != null:
				break
			await process_frame
		if visual._turn_tween != null:
			visual._turn_tween.pause()
		visual._set_page_turn_progress(0.5)
		await process_frame
		await process_frame
	elif capture_page_turn_sequence:
		journal._book.turn_to_spread(1)
		while journal._book.is_page_turning():
			await process_frame
		for frame in 4:
			await process_frame
	elif capture_reverse_turn_sequence:
		journal._book.turn_to_spread(0)
		while journal._book.is_page_turning():
			await process_frame
		for frame in 4:
			await process_frame
	var image := viewport.get_texture().get_image()
	var err := image.save_png(OUT)
	print("saved=", OUT, " err=", err, " size=", image.get_size())
	quit(err)
