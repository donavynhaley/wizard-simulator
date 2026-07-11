extends SceneTree

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const BOOK_SCENE := preload("res://scripts/components/book.tscn")

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
	for frame in 30:
		await process_frame
	close_event.pressed = false
	Input.parse_input_event(close_event)
	await process_frame
	_check(book.get_node_or_null("BookReadingOverlay") == null, "reading does not create a screen overlay")
	var hud := player.get_node("WizardHud") as WizardHud
	_check(hud._held_line.text.contains("Arrows pages"), "held hint updates to reading controls")
	var closed_visual := book.get_node("Visual/VisualRoot/ClosedVisual") as Node3D
	var open_visual := book.get_node("Visual/VisualRoot/OpenVisual") as Node3D
	var page_surface := book.get_node("Visual/VisualRoot/OpenVisual/PageSurface") as Sprite3D
	_check(not closed_visual.visible, "closed book model hides while reading")
	_check(open_visual.visible, "the reusable open visual shows while reading")
	_check(page_surface.visible and page_surface.texture != null, "physical page surface shows rendered content")
	_check(player.is_physics_processing(), "player can still move while reading")
	var reading_pose := book.get_node("Visual/ReadingPose") as Marker3D
	_check(visual_root.position.distance_to(reading_pose.position) < 0.01,
		"book visual scene owns the model-specific reading offset")
	_check(bool(grab_presentation.get("active")) and grab_presentation.has_item_aura(),
		"open held book continues floating with its subtle aura shader")
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
	_check((book.get_node("Visual/VisualRoot/OpenVisual/PageTurnPivot") as Node3D).visible,
		"page leaf is visible during the turn")
	await _wait_for_page_turn(book)
	_check(book.current_page == 1, "arrow key page input advances the held book after the animation")
	_check(left_title.text == "Second Spread", "page turn advances to the next authored spread")
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
