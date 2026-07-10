extends SceneTree

const BOOK_WRITER_SCENE := preload("res://scenes/content_tools/book_writer.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var writer := BOOK_WRITER_SCENE.instantiate() as BookWriter
	root.add_child(writer)
	await process_frame

	var save_path := "/tmp/book_writer_test.tres"
	(writer.get_node("%PathLineEdit") as LineEdit).text = save_path
	(writer.get_node("%IdLineEdit") as LineEdit).text = "book_writer_test"
	(writer.get_node("%TitleLineEdit") as LineEdit).text = "Book Writer Test"
	(writer.get_node("%DisplayNameLineEdit") as LineEdit).text = "Book Writer Test"
	(writer.get_node("%ThemeLineEdit") as LineEdit).text = "res://assets/themes/book_page_theme.tres"
	(writer.get_node("%LeftTitleLineEdit") as LineEdit).text = "Left Test"
	(writer.get_node("%LeftBodyEdit") as TextEdit).text = "Left body text"
	(writer.get_node("%RightTitleLineEdit") as LineEdit).text = "Right Test"
	(writer.get_node("%RightBodyEdit") as TextEdit).text = "Right body text"
	(writer.get_node("%RightRuneLineEdit") as LineEdit).text = "res://data/runes/templates/bolt/bolt_template_02.tres"
	var save_error := writer.call("_save_book") as Error
	if not _require(save_error == OK, "Book writer should report a successful save."):
		return

	var loaded := ResourceLoader.load(save_path) as BookData
	if not _require(loaded != null, "BookData should load after writer saves."):
		return
	if not _require(loaded.id == "book_writer_test", "Loaded BookData should keep id."):
		return
	if not _require(loaded.get_display_name() == "Book Writer Test", "Loaded BookData should keep display name."):
		return
	if not _require(loaded.page_theme != null, "Loaded BookData should keep its swappable page theme."):
		return
	if not _require(loaded.spreads.size() == 1, "Loaded BookData should keep spread count."):
		return
	var spread := loaded.spreads[0]
	if not _require(spread.left_page.body == "Left body text", "Loaded BookData should keep left page body."):
		return
	if not _require(spread.right_page.rune_template != null, "Loaded BookData should keep rune template reference."):
		return
	if not _require(spread.right_page.rune_template.rune_id == "bolt", "Loaded rune template should be Bolt."):
		return

	print("BOOK DATA TEST OK")
	quit()


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
