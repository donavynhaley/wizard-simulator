class_name BookPageRenderer
extends SubViewport

@export var default_page_theme: Theme

@onready var spread_root: Control = %SpreadRoot
@onready var left_title: Label = %LeftTitle
@onready var left_body: Label = %LeftBody
@onready var left_rune_view: RuneTemplateView = %LeftRuneView
@onready var right_title: Label = %RightTitle
@onready var right_body: Label = %RightBody
@onready var right_rune_view: RuneTemplateView = %RightRuneView
@onready var left_page_number: Label = %LeftPageNumber
@onready var right_page_number: Label = %RightPageNumber

var _rendering_active := false
var _rune_playback_enabled := true
var _book_data: BookData
var _fallback_title := "Untitled Book"
var _spread_index := 0
var _bookmark_column: VBoxContainer


func _ready() -> void:
	if default_page_theme == null:
		default_page_theme = spread_root.theme
	_refresh()
	_update_render_mode()


func show_spread(book_data: BookData, fallback_title: String, spread_index: int) -> void:
	_book_data = book_data
	_fallback_title = fallback_title
	_spread_index = spread_index
	_refresh()


func set_rendering_active(active: bool) -> void:
	_rendering_active = active
	_update_rune_playback()
	_update_render_mode()


func set_rune_playback_enabled(enabled: bool) -> void:
	_rune_playback_enabled = enabled
	_update_rune_playback()
	_update_render_mode()


## Freezes the currently rendered spread into an independent texture. Page
## turns use this for the outgoing sheet while this viewport pre-renders the
## destination spread underneath it.
func capture_snapshot() -> ImageTexture:
	if DisplayServer.get_name() == "headless":
		var placeholder := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		placeholder.fill(Color.WHITE)
		return ImageTexture.create_from_image(placeholder)
	var image := get_texture().get_image()
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


## Bookmark ribbon tabs down the outer edge of the right page. Pass an empty
## array to clear. The active tab is brighter and reaches further into the
## page, like the ribbon currently held between the pages.
func set_bookmarks(names: Array[String], active_index: int) -> void:
	if _bookmark_column == null:
		_bookmark_column = VBoxContainer.new()
		_bookmark_column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_bookmark_column.offset_left = -150.0
		_bookmark_column.offset_top = 60.0
		_bookmark_column.add_theme_constant_override("separation", 10)
		_bookmark_column.alignment = BoxContainer.ALIGNMENT_BEGIN
		spread_root.add_child(_bookmark_column)
	for child in _bookmark_column.get_children():
		_bookmark_column.remove_child(child)
		child.queue_free()
	for i in names.size():
		var active := i == active_index
		var tab := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.55, 0.16, 0.13, 0.95) if active else Color(0.35, 0.22, 0.14, 0.8)
		style.corner_radius_top_left = 8
		style.corner_radius_bottom_left = 8
		style.content_margin_left = 14.0
		style.content_margin_right = 10.0
		style.content_margin_top = 6.0
		style.content_margin_bottom = 6.0
		tab.add_theme_stylebox_override(&"panel", style)
		tab.custom_minimum_size = Vector2(150.0 if active else 110.0, 44.0)
		tab.size_flags_horizontal = Control.SIZE_SHRINK_END
		var label := Label.new()
		label.text = names[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override(&"font_color",
			Color(0.98, 0.92, 0.8) if active else Color(0.85, 0.78, 0.65))
		tab.add_child(label)
		_bookmark_column.add_child(tab)
	_bookmark_column.visible = not names.is_empty()
	_update_render_mode()
	if render_target_update_mode == SubViewport.UPDATE_DISABLED:
		return
	render_target_update_mode = SubViewport.UPDATE_ONCE


## Resolves a normalized spread coordinate against the visible bookmark tabs.
func bookmark_at_page_uv(page_uv: Vector2) -> int:
	if _bookmark_column == null \
			or page_uv.x < 0.0 or page_uv.x > 1.0 \
			or page_uv.y < 0.0 or page_uv.y > 1.0:
		return -1
	var viewport_point := page_uv * Vector2(size)
	for i in _bookmark_column.get_child_count():
		var tab := _bookmark_column.get_child(i) as Control
		if tab != null and tab.visible and tab.get_global_rect().has_point(viewport_point):
			return i
	return -1


func _refresh() -> void:
	if not is_node_ready():
		return
	spread_root.theme = _book_data.page_theme if _book_data != null and _book_data.page_theme != null else default_page_theme
	var spread := _current_spread()
	var left_page := spread.left_page if spread != null else null
	var right_page := spread.right_page if spread != null else null
	_apply_page(left_page, left_title, left_body, left_rune_view)
	_apply_page(right_page, right_title, right_body, right_rune_view)
	var page_count := maxi(_spread_count() * 2, 2)
	left_page_number.text = str(_spread_index * 2 + 1)
	right_page_number.text = "%d / %d" % [_spread_index * 2 + 2, page_count]
	_update_rune_playback()
	_update_render_mode()


func _apply_page(page: BookPageData, title: Label, body: Label, rune_view: RuneTemplateView) -> void:
	title.text = page.title if page != null else ""
	body.text = page.body if page != null else ""
	var show_rune := page != null and page.rune_template != null and page.show_rune_playback
	rune_view.visible = show_rune
	var strokes: Array[PackedVector2Array] = []
	if show_rune:
		strokes = page.rune_template.get_stroke_snapshot()
	rune_view.set_strokes(strokes)


func _current_spread() -> BookSpreadData:
	if _book_data == null or _book_data.get_spread_count() <= 0:
		var left := BookPageData.new()
		left.title = _fallback_title
		left.body = "The pages are blank."
		var spread := BookSpreadData.new()
		spread.left_page = left
		spread.right_page = BookPageData.new()
		return spread
	return _book_data.get_spread(_spread_index)


func _spread_count() -> int:
	return maxi(_book_data.get_spread_count(), 1) if _book_data != null else 1


func _update_rune_playback() -> void:
	if not is_node_ready():
		return
	var spread := _current_spread()
	_update_rune_view(left_rune_view, spread.left_page if spread != null else null)
	_update_rune_view(right_rune_view, spread.right_page if spread != null else null)


func _update_rune_view(rune_view: RuneTemplateView, page: BookPageData) -> void:
	var should_play := _rendering_active \
		and _rune_playback_enabled \
		and page != null \
		and page.rune_template != null \
		and page.show_rune_playback
	if should_play:
		if not rune_view.is_playback_active():
			rune_view.restart_playback()
	else:
		rune_view.stop_playback(true)


func _update_render_mode() -> void:
	if not is_node_ready():
		return
	var playing := left_rune_view.is_playback_active() or right_rune_view.is_playback_active()
	if not _rendering_active:
		render_target_update_mode = SubViewport.UPDATE_DISABLED
	elif playing:
		render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		render_target_update_mode = SubViewport.UPDATE_ONCE
