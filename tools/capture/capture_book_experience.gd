extends SceneTree

## Captures the two physical book-reading views used by the vertical slice.
## Run with a rendering display:
##   godot --path . -s tools/capture/capture_book_experience.gd

const HELD_OUT := "/tmp/book_held_view.png"
const TURN_OUT := "/tmp/book_page_turn_view.png"
const TURN_BACK_OUT := "/tmp/book_page_turn_back_view.png"
const TABLE_OUT := "/tmp/book_table_view.png"
const TABLE_BOOK_OUT := "/tmp/book_table_reference_view.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://game/world/levels/wizard_tower.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	var player := scene.get_node("Player") as WizardPlayer
	var book := _find_by_type(scene, "Book") as Book
	var crafter := scene.find_child("RuneScribingStation", true, false)
	var placement := scene.find_child("OpenBookPlacement", true, false) as OpenBookPlacement
	if player == null or book == null or crafter == null or placement == null:
		push_error("Book capture needs the tower player, book, crafter, and placement.")
		quit(1)
		return

	player.hands.pick_up(book)
	book.cast_from(player, player.get_viewport().get_camera_3d().global_transform)
	for frame in 20:
		await process_frame
	var error := _save_viewport(HELD_OUT)
	if error != OK:
		quit(error)
		return
	_add_capture_spread(book)
	book.call("_next_page")
	var turn_pivot := book.get_node("Visual/VisualRoot/OpenVisual/PageTurnPivot") as Node3D
	for frame in 120:
		if turn_pivot.visible and turn_pivot.rotation.z > 0.9:
			break
		await process_frame
	error = _save_viewport(TURN_OUT)
	if error != OK:
		quit(error)
		return
	for frame in 120:
		if turn_pivot.visible and turn_pivot.rotation.z > 2.3:
			break
		await process_frame
	error = _save_viewport(TURN_BACK_OUT)
	if error != OK:
		quit(error)
		return
	for frame in 120:
		if not book.is_page_turning():
			break
		await process_frame

	book.cast_from(player, player.get_viewport().get_camera_3d().global_transform)
	placement.place_book(book, player)
	crafter.call("_begin_scribing", player)
	for frame in 20:
		await process_frame
	error = _save_viewport(TABLE_OUT)
	if error != OK:
		quit(error)
		return
	var view_book_event := InputEventAction.new()
	view_book_event.action = &"move_forward"
	view_book_event.pressed = true
	crafter.call("_unhandled_input", view_book_event)
	for frame in 30:
		await process_frame
	error = _save_viewport(TABLE_BOOK_OUT)
	print("saved=", HELD_OUT, ", ", TURN_OUT, ", ", TURN_BACK_OUT, ", ", TABLE_OUT, ", and ", TABLE_BOOK_OUT)
	quit(error)


func _save_viewport(path: String) -> Error:
	var image := root.get_viewport().get_texture().get_image()
	return image.save_png(path)


func _add_capture_spread(book: Book) -> void:
	book.book_data = book.book_data.duplicate(true) as BookData
	var spread := BookSpreadData.new()
	var left := BookPageData.new()
	left.title = "Turning Pages"
	left.body = "Page content remains physical while the leaf crosses the book."
	var right := BookPageData.new()
	right.title = "Second Spread"
	right.body = "The renderer can show any number of authored spreads."
	spread.left_page = left
	spread.right_page = right
	book.book_data.spreads.append(spread)


func _find_by_type(node: Node, type_name: String) -> Node:
	if node.get_script() != null and node.get_script().get_global_name() == type_name:
		return node
	for child in node.get_children():
		var found := _find_by_type(child, type_name)
		if found != null:
			return found
	return null
