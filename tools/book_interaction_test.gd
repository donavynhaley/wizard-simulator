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
	await process_frame
	_check(book.get_node_or_null("BookReadingOverlay") == null, "reading does not create a screen overlay")
	_check(book.get_node("book_closed").visible == false, "closed book model hides while reading")
	_check(book.get_node("book_open").visible == true, "open book model shows while reading")
	_check(book.get_node("book_open_table").visible == false, "table book model stays hidden while reading")
	_check(book.get_node("book_open/PageContent").visible == true, "physical page content shows while reading")
	_check(book.get_node("book_open/PageContent/PageSurface").visible == true, "physical page surface shows while reading")
	_check(player.is_physics_processing(), "player can still move while reading")
	var left_title := book.get_node("BookPageViewport/SpreadRoot/Pages/LeftPage/Margin/LeftColumn/Title") as Label
	var right_title := book.get_node("BookPageViewport/SpreadRoot/Pages/RightPage/Margin/RightColumn/Title") as Label
	var rune_view := book.get_node("BookPageViewport/SpreadRoot/Pages/RightPage/Margin/RightColumn/RuneView") as Control
	var page_viewport := book.get_node("BookPageViewport") as SubViewport
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
	_check(book.current_page == 1, "arrow key page input advances the held book")
	_check(left_title.text == "Second Spread", "page turn advances to the next authored spread")

	Input.parse_input_event(cast_event)
	await process_frame
	_check(book.get_node("book_open/PageContent").visible == false, "closing hides physical page content")
	_check(book.get_node("book_open/PageContent/PageSurface").visible == false, "closing hides physical page surface")
	_check(not bool(rune_view.call("is_playback_active")), "closing stops rune stroke playback")
	_check(page_viewport.render_target_update_mode == SubViewport.UPDATE_ONCE,
		"book page viewport returns to one-shot rendering when closed")

	book.set_held(false)
	book.set_stationed(true)
	book.open_for_reference()
	_check(book.get_node("book_open").visible == false, "held book model hides on the table")
	_check(book.get_node("book_open_table").visible == true, "table book model shows for reference reading")
	_check(book.get_node("book_open_table/PageContent/PageSurface").visible == true,
		"table page surface shows for reference reading")
	book.current_page = 0
	book.call("_update_page_content")
	book._input(move_right_event)
	_check(book.current_page == 0, "table book does not turn pages outside scribing")
	book.set_reference_page_turn_enabled(true)
	book._input(move_right_event)
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
