extends SceneTree

## Exercises the shipped main scene through Godot's real input pipeline and
## captures the journal after Escape. This intentionally does not call the
## JournalMenu input handler directly.

const OUT := "/tmp/live_journal_view.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene_path := ProjectSettings.get_setting(
		"application/run/main_scene", "") as String
	var packed_scene := load(main_scene_path) as PackedScene
	if packed_scene == null:
		push_error("Unable to load main scene: %s" % main_scene_path)
		quit(1)
		return
	var world := packed_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var player := get_first_node_in_group(&"player") as WizardPlayer
	var journal := player.get_node_or_null("Components/JournalMenu") as JournalMenu \
		if player != null else null
	for frame in 10:
		if journal != null and journal._book != null:
			break
		await process_frame
	if journal == null or journal._book == null:
		push_error("Live journal was not built")
		quit(1)
		return

	var escape_down := InputEventKey.new()
	escape_down.keycode = KEY_ESCAPE
	escape_down.physical_keycode = KEY_ESCAPE
	escape_down.pressed = true
	Input.parse_input_event(escape_down)
	await process_frame
	var escape_up := escape_down.duplicate() as InputEventKey
	escape_up.pressed = false
	Input.parse_input_event(escape_up)

	for frame in 360:
		if frame % 30 == 0:
			var arm_player := journal._element_hand._left_arm_anim as AnimationPlayer
			print(
				"LIVE_JOURNAL frame=", frame,
				" open=", journal.is_open(),
				" transitioning=", journal.is_transitioning(),
				" progress=", journal.summon_progress,
				" book_visible=", journal._book.visible,
				" animation=", journal._summon_animation.current_animation,
				" playing=", journal._summon_animation.is_playing(),
				" arm_animation=", arm_player.current_animation,
				" arm_position=", arm_player.current_animation_position,
				" arm_length=", arm_player.current_animation_length,
				" arm_playing=", arm_player.is_playing())
		if not journal.is_transitioning() and journal.summon_progress >= 0.999:
			break
		await process_frame
	# Let the viewport page texture and final book transform settle together.
	await process_frame
	await process_frame

	var image := root.get_texture().get_image()
	if image == null:
		print("capture unavailable with the current rendering driver")
		quit(0)
		return
	var error := image.save_png(OUT)
	print("saved=", OUT, " err=", error, " size=", image.get_size())
	quit(error)
