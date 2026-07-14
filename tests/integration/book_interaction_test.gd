extends SceneTree

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

	_check(book.focus_prompt(player, null).begins_with("Pick up"), "book prompts pickup with empty hands")
	book.interact(player, null)
	_check(player.hands.held_item == book, "player can pick up the book")
	var grab_presentation := player.hands.get_grab_presentation()
	_check(grab_presentation != null and bool(grab_presentation.get("active")),
		"closed held book uses the magical levitation presentation")
	_check(grab_presentation.has_item_aura(), "closed held book receives the item aura shader")
	for frame in 20:
		await process_frame
	var item_anchor := grab_presentation.get_item_anchor() as Node3D
	var visual_root := book.get_node("Visual/VisualRoot") as Node3D
	var held_pose := book.get_node("Visual/HeldPose") as Marker3D
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
	_check(book.get_parent() == item_anchor, "held book uses the common floating item anchor")
	_check(book.position.distance_to(Vector3.ZERO) < 0.001,
		"held book root stays aligned with the common item anchor")
	_check(visual_root.position.distance_to(held_pose.position) < 0.001,
		"book visual scene owns the model-specific held offset")
	_check(book.get_display_name() == "Bolt Rune Book", "rune book display name comes from the rune template")
	_check(book.get_held_hint().contains("LMB read"), "held book explains read input")

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var cast_event := InputEventMouseButton.new()
	cast_event.button_index = MOUSE_BUTTON_LEFT
	cast_event.pressed = true
	var close_event := InputEventMouseButton.new()
	close_event.button_index = MOUSE_BUTTON_LEFT
	close_event.pressed = true
	Input.parse_input_event(close_event)
	for frame in 50:
		await process_frame
	close_event.pressed = false
	Input.parse_input_event(close_event)
	await process_frame
	_check(book.get_node_or_null("BookReadingOverlay") == null, "reading does not create a screen overlay")
	var hud := player.get_node("WizardHud") as WizardHud
	_check(hud._held_line.text.contains("Arrows pages"), "held hint updates to reading controls")
	var closed_visual := book.get_node("Visual/VisualRoot/MotionRoot/ClosedVisual") as Node3D
	var open_visual := book.get_node("Visual/VisualRoot/MotionRoot/OpenVisual") as Node3D
	var page_surface := book.get_node(
		"Visual/VisualRoot/MotionRoot/OpenVisual/PageSurface") as Node3D
	var left_page_surface := book.get_node_or_null(
		"Visual/VisualRoot/MotionRoot/OpenVisual/PageSurface/LeftPage") as MeshInstance3D
	var right_page_surface := book.get_node_or_null(
		"Visual/VisualRoot/MotionRoot/OpenVisual/PageSurface/RightPage") as MeshInstance3D
	var left_page_stack := book.get_node_or_null(
		"Visual/VisualRoot/MotionRoot/OpenVisual/PageSurface/LeftPageStack") as MeshInstance3D
	var right_page_stack := book.get_node_or_null(
		"Visual/VisualRoot/MotionRoot/OpenVisual/PageSurface/RightPageStack") as MeshInstance3D
	_check(not closed_visual.visible, "closed book model hides while reading")
	_check(open_visual.visible, "the reusable open visual shows while reading")
	_check(left_page_surface != null and right_page_surface != null,
		"open book renders its spread on separate physical page meshes")
	_check(left_page_surface != null and left_page_surface.mesh.get_aabb().size.y > 0.004
		and right_page_surface != null and right_page_surface.mesh.get_aabb().size.y > 0.004,
		"both reading pages curve upward from the cover")
	_check(left_page_stack != null and right_page_stack != null,
		"open book shows physical page thickness beneath the active spread")
	_check(player.is_physics_processing(), "player can still move while reading")
	var reading_pose := book.get_node("Visual/ReadingPose") as Marker3D
	_check(visual_root.position.distance_to(reading_pose.position) < 0.01,
		"book visual scene owns the model-specific reading offset")
	_check(reading_pose.scale.x < 1.5,
		"default reading composition keeps the physical book inside the viewport")
	var camera := player.get_viewport().get_camera_3d()
	var spread_bounds := _get_spread_screen_bounds(
		camera,
		page_surface,
		(book.book_data.visual_profile as BookVisualProfile).spread_size)
	var viewport_size := player.get_viewport().get_visible_rect().size
	var spread_width_ratio := spread_bounds.size.x / viewport_size.x
	_check(spread_bounds.position.x > viewport_size.x * 0.04
		and spread_bounds.end.x < viewport_size.x * 0.96
		and spread_bounds.position.y > viewport_size.y * 0.04
		and spread_bounds.end.y < viewport_size.y * 0.96,
		"the default physical spread preserves visible world around every edge")
	_check(spread_width_ratio > 0.3 and spread_width_ratio < 0.8,
		"the default physical spread is readable without becoming a full-screen panel")
	_check(bool(grab_presentation.get("active")) and grab_presentation.has_item_aura(),
		"open held book continues floating with its subtle aura shader")
	var first_person_rig := player.body_rig.get_first_person_rig()
	var reading_grips := book.get_reading_hand_grips()
	_check(first_person_rig != null and first_person_rig.get_reading_book() == book,
		"opening a book gives the first-person rig a physical reading target")
	_check(reading_grips.size() == 2
		and first_person_rig.left_hand_target.global_position.distance_to(
			reading_grips[0].origin) < 0.02
		and first_person_rig.right_hand_target.global_position.distance_to(
			reading_grips[1].origin) < 0.02,
		"both first-person hands support profile-authored book contacts")
	_check(book.get_held_hint().contains("RMB focus"),
		"reading hint exposes the optional close-focus control")
	var focus_event := InputEventAction.new()
	focus_event.action = &"book_focus"
	focus_event.pressed = true
	book._input(focus_event)
	for frame in 30:
		await process_frame
	var book_visual := book.get_node("Visual") as BookVisual
	_check(book_visual.is_close_focused(), "holding focus brings the physical book closer")
	focus_event.pressed = false
	book._input(focus_event)
	for frame in 30:
		await process_frame
	_check(not book_visual.is_close_focused(), "releasing focus restores the grounded reading pose")
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
	_check(right_page_stack.mesh.get_aabb().size.y > left_page_stack.mesh.get_aabb().size.y,
		"the unread side carries the thicker physical page stack")
	var move_right_event := InputEventAction.new()
	move_right_event.action = &"move_right"
	move_right_event.pressed = true
	book._input(move_right_event)
	_check(book.current_page == 0, "movement input does not turn held-book pages")
	var next_event := InputEventAction.new()
	next_event.action = &"ui_right"
	next_event.pressed = true
	book._input(next_event)
	_check(book.is_page_turning(), "arrow key input starts the physical page-turn animation")
	var right_hand_before_turn := first_person_rig.right_hand_target.global_position
	var turning_page := book.get_node_or_null(
		"Visual/VisualRoot/MotionRoot/OpenVisual/PageSurface/TurningPage") as MeshInstance3D
	for frame in 8:
		await process_frame
	_check(turning_page != null and turning_page.visible,
		"page leaf is visible during the turn")
	_check(turning_page != null and turning_page.mesh.get_aabb().size.y > 0.01,
		"turning page curls above the resting spread")
	_check(first_person_rig.right_hand_target.global_position.distance_to(
		right_hand_before_turn) > 0.005,
		"the turning-side hand follows the curling page leaf")
	await _wait_for_page_turn(book)
	_check(book.current_page == 1, "arrow key page input advances the held book after the animation")
	_check(left_title.text == "Second Spread", "page turn advances to the next authored spread")
	_check(left_page_stack.mesh.get_aabb().size.y > right_page_stack.mesh.get_aabb().size.y,
		"turning a spread transfers visible page thickness across the spine")
	var previous_event := InputEventAction.new()
	previous_event.action = &"ui_left"
	previous_event.pressed = true
	book._input(previous_event)
	_check(book.is_page_turning(), "left arrow starts the reverse physical page-turn animation")
	await _wait_for_page_turn(book)
	_check(book.current_page == 0 and left_title.text == "Bolt Rune",
		"reverse page turn returns to the previous authored spread")
	book._input(next_event)
	await _wait_for_page_turn(book)
	_check(book.current_page == 1, "a forward turn still works after reversing the page leaf")

	Input.parse_input_event(cast_event)
	for frame in 120:
		if not open_visual.visible:
			break
		await process_frame
	_check(not open_visual.visible, "closing hides the reusable open visual")
	_check(hud._held_line.text.contains("LMB read"), "held hint returns to the closed-book controls")
	_check(not bool(rune_view.call("is_playback_active")), "closing stops rune stroke playback")
	_check(page_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"book page viewport stops rendering when closed")
	_check(bool(grab_presentation.get("active")),
		"closing a held book keeps the magical levitation presentation")
	_check(first_person_rig.get_reading_book() == null,
		"closing returns the hands to their regular held-item pose")

	player.hands.release_item(book)
	book.set_stationed(true)
	book.open_for_reference()
	_check(open_visual.visible, "the same open visual shows for table reference reading")
	_check(page_surface.visible, "table page surface shows for reference reading")
	book.current_page = 0
	book.call("_update_page_content")
	book._input(move_right_event)
	_check(book.current_page == 0, "table book does not turn pages outside scribing")
	book.set_reference_page_turn_enabled(true)
	book._input(move_right_event)
	await _wait_for_page_turn(book)
	_check(book.current_page == 1, "table book turns pages when reference page turns are enabled")

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


func _get_spread_screen_bounds(
		camera: Camera3D,
		page_surface: Node3D,
		spread_size: Vector2) -> Rect2:
	var half_width := spread_size.x * 0.5
	var half_height := spread_size.y * 0.5
	var local_corners := [
		Vector3(-half_width, 0.0, -half_height),
		Vector3(half_width, 0.0, -half_height),
		Vector3(half_width, 0.0, half_height),
		Vector3(-half_width, 0.0, half_height),
	]
	var first_point := camera.unproject_position(page_surface.to_global(local_corners[0]))
	var bounds := Rect2(first_point, Vector2.ZERO)
	for index in range(1, local_corners.size()):
		bounds = bounds.expand(camera.unproject_position(
			page_surface.to_global(local_corners[index])))
	return bounds
