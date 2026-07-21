extends SceneTree

## The journal pause menu (game-bible.md: the journal is the infinite book and
## the main menu). Escape opens the journal book into the reading pose and
## freezes the player; Tab flips bookmarks between sections; Escape inside the
## book closes it and restores control. The rune section carries all six verb
## glyphs with playback templates.

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(50.0, 1.0, 50.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	floor_body.global_position = Vector3(0.0, -0.5, 0.0)

	var player := (load("res://game/player/player.tscn") as PackedScene).instantiate() as WizardPlayer
	root.add_child(player)
	await process_frame
	await process_frame

	var journal := player.get_node_or_null("Components/JournalMenu") as JournalMenu
	_check(journal != null, "player carries a JournalMenu")
	if journal == null:
		_finish(player)
		return
	await process_frame  # deferred book build
	_check(journal._book != null, "the journal book is mounted under the camera")
	if journal._book == null:
		_finish(player)
		return

	var data: BookData = journal._book.book_data
	_check(data.get_spread_count() == 4, "journal has a menu spread and three rune spreads")
	var rune_pages := 0
	for i in range(1, data.get_spread_count()):
		var spread := data.get_spread(i)
		for page in [spread.left_page, spread.right_page]:
			if page != null and page.rune_template != null and page.show_rune_playback:
				rune_pages += 1
	_check(rune_pages == 6, "all six verb glyphs have playback pages")

	# Escape opens the journal and freezes the player.
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	journal._unhandled_input(escape)
	await process_frame
	_check(journal.is_open(), "escape opens the journal")
	_check(journal._book.is_reading(), "the journal book enters the reading pose")
	_check(journal._book.visible, "the journal book is visible while open")
	_check(not player.control_enabled(), "the player freezes while reading the journal")
	_check(journal._book.current_page == 0, "the journal opens on the menu spread")

	# Tab flips to the Runes bookmark.
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	journal._unhandled_input(tab)
	await process_frame
	_check(journal._book.current_page == 1, "tab flips to the runes bookmark")
	journal._unhandled_input(tab)
	await process_frame
	_check(journal._book.current_page == 0, "tab wraps back to the menu bookmark")

	# Escape inside the book closes it and restores control.
	journal._book._input(escape)
	await process_frame
	_check(not journal.is_open(), "escape closes the journal")
	_check(not journal._book.visible, "the closed journal hides")
	_check(player.control_enabled(), "closing the journal restores the player")

	# Resume via the menu action ([1]) after reopening.
	journal._unhandled_input(escape)
	await process_frame
	_check(journal.is_open(), "the journal reopens")
	var one := InputEventKey.new()
	one.keycode = KEY_1
	one.pressed = true
	journal._unhandled_input(one)
	await process_frame
	_check(not journal.is_open(), "the resume entry closes the journal")
	_check(player.control_enabled(), "resume restores the player")

	_finish(player)


func _finish(player: Node) -> void:
	if player != null:
		player.queue_free()
	await process_frame
	await process_frame
	if _fail == 0:
		print("JOURNAL MENU TEST OK")
	quit(_fail)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		push_error("[FAIL] %s" % message)
		_fail = 1
