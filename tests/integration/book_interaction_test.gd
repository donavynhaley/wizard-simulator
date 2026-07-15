extends SceneTree

## Checks the book's data-driven visuals and table reference reading. The
## held/read-in-hand flow is dormant until the custody rework lands. Run:
##   godot --headless --path . -s tests/integration/book_interaction_test.gd

const PLAYER_SCENE := preload("res://game/player/player.tscn")
const BOOK_SCENE := preload("res://game/books/book.tscn")

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world

	var player := PLAYER_SCENE.instantiate() as WizardPlayer
	world.add_child(player)
	var book := BOOK_SCENE.instantiate() as Book
	world.add_child(book)
	await process_frame
	_check(InputMap.has_action(&"book_focus"),
		"book focus has a keyboard, mouse, and controller-ready input action")

	var visual_profile := book.book_data.get("visual_profile") as Resource
	var closed_model_socket := book.get_node_or_null(
		"Visual/VisualRoot/MotionRoot/ClosedVisual/ModelSocket") as Node3D
	var open_model_socket := book.get_node_or_null(
		"Visual/VisualRoot/MotionRoot/OpenVisual/ModelSocket") as Node3D
	_check(visual_profile != null, "book content selects a reusable visual profile")
	_check(closed_model_socket != null and closed_model_socket.get_child_count() == 1,
		"book visual instantiates its closed model through a model socket")
	_check(open_model_socket != null and open_model_socket.get_child_count() == 1,
		"book visual instantiates its open model through a model socket")
	_check(book.get_display_name() == "Bolt Rune Book",
		"rune book display name comes from the rune template")

	# Table reference reading (the crafter-facing flow, no hands involved).
	book.set_stationed(true)
	book.open_for_reference()
	await process_frame
	var closed_visual := book.get_node("Visual/VisualRoot/MotionRoot/ClosedVisual") as Node3D
	var open_visual := book.get_node("Visual/VisualRoot/MotionRoot/OpenVisual") as Node3D
	var page_surface := book.get_node(
		"Visual/VisualRoot/MotionRoot/OpenVisual/PageSurface") as Node3D
	_check(not closed_visual.visible, "closed book model hides for reference reading")
	_check(open_visual.visible, "the reusable open visual shows for table reference reading")
	_check(page_surface.visible, "table page surface shows for reference reading")

	var left_title := book.get_node("PageRenderer/SpreadRoot/Pages/LeftPage/Margin/Column/LeftTitle") as Label
	var right_title := book.get_node("PageRenderer/SpreadRoot/Pages/RightPage/Margin/Column/RightTitle") as Label
	var rune_view := book.get_node("PageRenderer/SpreadRoot/Pages/RightPage/Margin/Column/RightRuneView") as RuneTemplateView
	var page_viewport := book.get_node("PageRenderer") as SubViewport
	var left_page := book.get_node("PageRenderer/SpreadRoot/Pages/LeftPage") as PanelContainer
	var right_page := book.get_node("PageRenderer/SpreadRoot/Pages/RightPage") as PanelContainer
	var left_paper := left_page.get_theme_stylebox("panel") as StyleBoxFlat
	var right_paper := right_page.get_theme_stylebox("panel") as StyleBoxFlat
	var expected_paper_color := Color("#fce08c")
	_check(left_paper.bg_color.is_equal_approx(expected_paper_color)
		and right_paper.bg_color.is_equal_approx(expected_paper_color),
		"both physical book pages use the authored palette paper color")
	_check(left_title.text == "Bolt Rune", "book writes its authored left page title")
	_check(right_title.text == "Scribing Pattern", "book writes its authored right page title")
	_check(rune_view.visible, "rune book shows the rune template on its page")
	_check(bool(rune_view.call("is_playback_active")), "rune page starts stroke playback")
	_check(page_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"book page viewport updates continuously during rune playback")
	_check(book.has_loaded_rune_template(), "rune book loads template strokes")

	# Reference page turning stays gated behind the scribing station toggle.
	book.book_data = book.book_data.duplicate(true) as BookData
	var extra_spread := BookSpreadData.new()
	var extra_left := BookPageData.new()
	extra_left.title = "Second Spread"
	extra_left.body = "second spread left"
	var extra_right := BookPageData.new()
	extra_right.title = "Third Page"
	extra_right.body = "second spread right"
	extra_spread.left_page = extra_left
	extra_spread.right_page = extra_right
	book.book_data.spreads.append(extra_spread)
	book.current_page = 0
	book.call("_update_page_content")
	var move_right_event := InputEventAction.new()
	move_right_event.action = &"move_right"
	move_right_event.pressed = true
	book._input(move_right_event)
	_check(book.current_page == 0, "table book does not turn pages outside scribing")
	book.set_reference_page_turn_enabled(true)
	book._input(move_right_event)
	await _wait_for_page_turn(book)
	_check(book.current_page == 1,
		"table book turns pages when reference page turns are enabled")
	_check(left_title.text == "Second Spread", "page turn advances to the next authored spread")

	# Visual profiles rebuild the shared physical book from arbitrary models.
	var visual_scene := load(
		"res://game/books/presentation/default_book_visual.tscn") as PackedScene
	var replacement_visual := visual_scene.instantiate() as BookVisual
	world.add_child(replacement_visual)
	await process_frame
	var replacement_profile := BookVisualProfile.new()
	replacement_profile.closed_model_scene = load(
		"res://assets/models/book_open.glb") as PackedScene
	replacement_profile.open_model_scene = load(
		"res://assets/models/book_closed.glb") as PackedScene
	replacement_profile.closed_model_transform.origin = Vector3(0.03, 0.02, -0.01)
	replacement_profile.spread_size = Vector2(0.48, 0.22)
	replacement_profile.left_hand_grip.origin = Vector3(-0.2, 0.01, 0.08)
	replacement_profile.right_hand_grip.origin = Vector3(0.2, 0.01, 0.08)
	replacement_visual.apply_profile(replacement_profile)
	var replacement_closed := replacement_visual.get_node(
		"VisualRoot/MotionRoot/ClosedVisual/ModelSocket/ClosedModel") as Node3D
	var replacement_left_page := replacement_visual.get_node(
		"VisualRoot/MotionRoot/OpenVisual/PageSurface/LeftPage") as MeshInstance3D
	_check(replacement_closed.scene_file_path == "res://assets/models/book_open.glb"
		and replacement_closed.position.is_equal_approx(Vector3(0.03, 0.02, -0.01)),
		"visual profiles accept arbitrary imported model scenes and alignment")
	_check(is_equal_approx(replacement_left_page.mesh.get_aabb().size.z, 0.22),
		"replacement profile dimensions rebuild the shared physical page geometry")
	var replacement_grips := replacement_visual.get_hand_grip_transforms()
	_check(replacement_grips.size() == 2
		and replacement_visual.to_local(replacement_grips[0].origin).is_equal_approx(
			Vector3(-0.2, 0.01, 0.08))
		and replacement_visual.to_local(replacement_grips[1].origin).is_equal_approx(
			Vector3(0.2, 0.01, 0.08)),
		"replacement profiles carry their own two-hand contact points")
	replacement_visual.queue_free()

	world.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _fail == 0:
		print("BOOK INTERACTION TEST OK")
	else:
		print("BOOK INTERACTION TEST FAILURES: ", _fail)
	quit(_fail)


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("[PASS] ", msg)
	else:
		_fail += 1
		push_error("[FAIL] " + msg)


func _wait_for_page_turn(book: Book) -> void:
	for frame in 120:
		if not book.is_page_turning():
			return
		await process_frame
