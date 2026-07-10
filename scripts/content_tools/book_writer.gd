extends Control
class_name BookWriter

const BookDataResource := preload("res://scripts/components/book_data.gd")
const BookPageDataResource := preload("res://scripts/components/book_page_data.gd")
const BookSpreadDataResource := preload("res://scripts/components/book_spread_data.gd")
const BOOK_SCENE := preload("res://scripts/components/book.tscn")

@export_dir var output_directory: String = "res://data/books"
@export var default_save_path: String = "res://data/books/new_book.tres"

@onready var path_line_edit: LineEdit = %PathLineEdit
@onready var id_line_edit: LineEdit = %IdLineEdit
@onready var title_line_edit: LineEdit = %TitleLineEdit
@onready var display_name_line_edit: LineEdit = %DisplayNameLineEdit
@onready var spread_spin_box: SpinBox = %SpreadSpinBox
@onready var left_title_line_edit: LineEdit = %LeftTitleLineEdit
@onready var left_body_edit: TextEdit = %LeftBodyEdit
@onready var left_rune_line_edit: LineEdit = %LeftRuneLineEdit
@onready var right_title_line_edit: LineEdit = %RightTitleLineEdit
@onready var right_body_edit: TextEdit = %RightBodyEdit
@onready var right_rune_line_edit: LineEdit = %RightRuneLineEdit
@onready var status_label: Label = %StatusLabel
@onready var preview_root: Node3D = %PreviewRoot

var book_data: BookData
var _preview_book: Book
var _active_spread_index := 0
var _syncing_fields := false


func _ready() -> void:
	_wire_buttons()
	_create_preview()
	_new_book()


func _wire_buttons() -> void:
	%NewButton.pressed.connect(_new_book)
	%LoadButton.pressed.connect(_load_book)
	%SaveButton.pressed.connect(_save_book)
	%AddSpreadButton.pressed.connect(_add_spread)
	spread_spin_box.value_changed.connect(_on_spread_index_changed)
	for control in [
		id_line_edit,
		title_line_edit,
		display_name_line_edit,
		left_title_line_edit,
		left_rune_line_edit,
		right_title_line_edit,
		right_rune_line_edit,
	]:
		control.text_changed.connect(_on_text_field_changed)
	left_body_edit.text_changed.connect(_on_text_body_changed)
	right_body_edit.text_changed.connect(_on_text_body_changed)


func _new_book() -> void:
	book_data = BookDataResource.new()
	book_data.id = "new_book"
	book_data.title = "New Book"
	book_data.display_name = "New Book"
	book_data.spreads.clear()
	book_data.spreads.append(_new_blank_spread())
	path_line_edit.text = default_save_path
	_active_spread_index = 0
	_sync_fields_from_resource()
	_set_status("Created a new book resource.", false)


func _load_book() -> void:
	var path := path_line_edit.text.strip_edges()
	var resource := ResourceLoader.load(path)
	if resource is not BookData:
		_set_status("Could not load BookData from %s." % path, true)
		return
	book_data = resource as BookData
	if book_data.spreads.is_empty():
		book_data.spreads.append(_new_blank_spread())
	_active_spread_index = 0
	_sync_fields_from_resource()
	_set_status("Loaded %s." % path, false)


func _save_book() -> void:
	_sync_resource_from_fields()
	var path := path_line_edit.text.strip_edges()
	if path.is_empty():
		path = default_save_path
		path_line_edit.text = path
	var directory_error := _ensure_output_directory(path.get_base_dir())
	if directory_error != OK:
		_set_status("Could not create output directory: %s" % error_string(directory_error), true)
		return
	var save_error := ResourceSaver.save(book_data, path)
	if save_error != OK:
		_set_status("Save failed: %s" % error_string(save_error), true)
		return
	_set_status("Saved %s." % path, false)


func _add_spread() -> void:
	_sync_resource_from_fields()
	book_data.spreads.append(_new_blank_spread())
	_active_spread_index = book_data.spreads.size() - 1
	_sync_fields_from_resource()
	_set_status("Added spread %d." % (_active_spread_index + 1), false)


func _on_spread_index_changed(value: float) -> void:
	if _syncing_fields:
		return
	_sync_resource_from_fields()
	_active_spread_index = clampi(int(value) - 1, 0, maxi(book_data.spreads.size() - 1, 0))
	_sync_fields_from_resource()


func _on_text_field_changed(_new_text: String) -> void:
	if not _syncing_fields:
		_sync_resource_from_fields()
		_refresh_preview()


func _on_text_body_changed() -> void:
	if not _syncing_fields:
		_sync_resource_from_fields()
		_refresh_preview()


func _sync_resource_from_fields() -> void:
	if book_data == null:
		return
	book_data.id = id_line_edit.text.strip_edges()
	book_data.title = title_line_edit.text.strip_edges()
	book_data.display_name = display_name_line_edit.text.strip_edges()
	var spread := _selected_spread()
	spread.left_page = _page_from_fields(left_title_line_edit, left_body_edit, left_rune_line_edit)
	spread.right_page = _page_from_fields(right_title_line_edit, right_body_edit, right_rune_line_edit)


func _sync_fields_from_resource() -> void:
	if book_data == null:
		return
	_syncing_fields = true
	id_line_edit.text = book_data.id
	title_line_edit.text = book_data.title
	display_name_line_edit.text = book_data.display_name
	spread_spin_box.min_value = 1.0
	spread_spin_box.max_value = maxf(float(book_data.spreads.size()), 1.0)
	spread_spin_box.value = float(_active_spread_index + 1)
	var spread := _selected_spread()
	_apply_page_to_fields(spread.left_page, left_title_line_edit, left_body_edit, left_rune_line_edit)
	_apply_page_to_fields(spread.right_page, right_title_line_edit, right_body_edit, right_rune_line_edit)
	_syncing_fields = false
	_refresh_preview()


func _page_from_fields(title_field: LineEdit, body_field: TextEdit, rune_field: LineEdit) -> BookPageData:
	var page := BookPageDataResource.new()
	page.title = title_field.text.strip_edges()
	page.body = body_field.text
	page.rune_template = _load_rune_template(rune_field.text.strip_edges())
	page.show_rune_playback = page.rune_template != null
	return page


func _apply_page_to_fields(page: BookPageData, title_field: LineEdit, body_field: TextEdit, rune_field: LineEdit) -> void:
	if page == null:
		title_field.text = ""
		body_field.text = ""
		rune_field.text = ""
		return
	title_field.text = page.title
	body_field.text = page.body
	rune_field.text = page.rune_template.resource_path if page.rune_template != null else ""


func _selected_spread() -> BookSpreadData:
	if book_data.spreads.is_empty():
		book_data.spreads.append(_new_blank_spread())
	_active_spread_index = clampi(_active_spread_index, 0, book_data.spreads.size() - 1)
	var spread := book_data.spreads[_active_spread_index]
	if spread == null:
		spread = _new_blank_spread()
		book_data.spreads[_active_spread_index] = spread
	if spread.left_page == null:
		spread.left_page = BookPageDataResource.new()
	if spread.right_page == null:
		spread.right_page = BookPageDataResource.new()
	return spread


func _new_blank_spread() -> BookSpreadData:
	var spread := BookSpreadDataResource.new()
	spread.left_page = BookPageDataResource.new()
	spread.right_page = BookPageDataResource.new()
	return spread


func _load_rune_template(path: String) -> RuneTemplate:
	if path.is_empty():
		return null
	var resource := ResourceLoader.load(path)
	return resource as RuneTemplate


func _create_preview() -> void:
	_preview_book = BOOK_SCENE.instantiate() as Book
	preview_root.add_child(_preview_book)
	_preview_book.position = Vector3.ZERO
	_preview_book.rotation_degrees = Vector3(180,0,0)
	_preview_book.set_stationed(true)
	_preview_book.open_for_reference()


func _refresh_preview() -> void:
	if _preview_book == null or book_data == null:
		return
	_preview_book.book_data = book_data
	_preview_book.current_page = _active_spread_index
	_preview_book.call_deferred("_update_page_content")
	_preview_book.open_for_reference()


func _ensure_output_directory(path: String) -> Error:
	if path.begins_with("res://") or path.begins_with("user://"):
		return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	return DirAccess.make_dir_recursive_absolute(path)


func _set_status(message: String, is_error: bool) -> void:
	status_label.text = message
	if is_error:
		push_warning(message)
