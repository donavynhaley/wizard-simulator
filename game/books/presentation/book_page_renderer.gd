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
