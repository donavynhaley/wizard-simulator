extends Item
class_name Book

## Books contain words and images to convey information to the player
## they can have opened and closed states
## they can have up to 10 pages worth of information
## when a book is held in a players hand it is closed.
## when a book is held in a players hand and they hold left click the book opens and is focused
## in the focused mode the book moves closer to the camera and its contents can be easily read
## the player can flip held-book pages with the arrow keys while reading
## a book can be placed on the crafting table
## when its place it is open
## when a player has a book on the table and is in scribe mode they can flip the pages with a & d

@export var book_data: BookData
@export_group("Held Open Visual")
@export_node_path("Node3D") var held_page_content_path: NodePath = ^"book_open/PageContent"
@export_node_path("MeshInstance3D") var held_page_surface_path: NodePath = ^"book_open/PageContent/PageSurface"
@export_group("Table Open Visual")
@export_node_path("Node3D") var table_open_model_path: NodePath = ^"book_open_table"
@export_node_path("Node3D") var table_page_content_path: NodePath = ^"book_open_table/PageContent"
@export_node_path("MeshInstance3D") var table_page_surface_path: NodePath = ^"book_open_table/PageContent/PageSurface"
@export_group("Page Content")
@export var flip_page_texture_horizontal := false
@export var flip_page_texture_vertical := true
@export_node_path("SubViewport") var page_viewport_path: NodePath = ^"BookPageViewport"
@export_node_path("Label") var left_title_label_path: NodePath = ^"BookPageViewport/SpreadRoot/Pages/LeftPage/Margin/LeftColumn/Title"
@export_node_path("Label") var left_body_label_path: NodePath = ^"BookPageViewport/SpreadRoot/Pages/LeftPage/Margin/LeftColumn/Body"
@export_node_path("Control") var left_rune_view_path: NodePath = ^"BookPageViewport/SpreadRoot/Pages/LeftPage/Margin/LeftColumn/RuneView"
@export_node_path("Label") var right_title_label_path: NodePath = ^"BookPageViewport/SpreadRoot/Pages/RightPage/Margin/RightColumn/Title"
@export_node_path("Label") var right_body_label_path: NodePath = ^"BookPageViewport/SpreadRoot/Pages/RightPage/Margin/RightColumn/Body"
@export_node_path("Control") var right_rune_view_path: NodePath = ^"BookPageViewport/SpreadRoot/Pages/RightPage/Margin/RightColumn/RuneView"
@export_node_path("Label") var footer_label_path: NodePath = ^"BookPageViewport/SpreadRoot/Footer"
@export var autoplay_rune_stroke_playback := true
@export_group("Held Pose")
@export var held_position := Vector3(0.02, -0.02, -0.18)
@export var held_rotation := Vector3(-0.78, 0.0, 0.0)
@export var held_scale := Vector3.ONE
@export_group("Reading Pose")
@export var reading_position := Vector3(-0.18, -0.08, -0.36)
@export var reading_rotation := Vector3(1.08, PI, 0.0)
@export var reading_scale := Vector3(1.15, 1.15, 1.15)
@export var reading_pose_time := 0.18

@export_group("Physics")
@export_flags_3d_physics var active_collision_layer: int = 2
@export_flags_3d_physics var active_collision_mask: int = 1

var current_page := 0
var _is_held := false
var _is_stationed := false
var _is_reference_open := false
var _reference_page_turn_enabled := false
var _is_reading := false
var _reader: WizardPlayer
var _held_page_content: Node3D
var _held_page_surface: MeshInstance3D
var _table_page_content: Node3D
var _table_page_surface: MeshInstance3D
var _page_viewport: SubViewport
var _left_title_label: Label
var _left_body_label: Label
var _left_rune_view: Control
var _right_title_label: Label
var _right_body_label: Label
var _right_rune_view: Control
var _footer_label: Label
var _closed_model: Node3D
var _held_open_model: Node3D
var _table_open_model: Node3D
var _pose_tween: Tween


func _ready() -> void:
	_closed_model = get_node_or_null("book_closed") as Node3D
	_held_open_model = get_node_or_null("book_open") as Node3D
	_table_open_model = get_node_or_null(table_open_model_path) as Node3D
	_cache_page_nodes()
	_apply_page_viewport_to_surface()
	_update_page_content()
	_refresh_model_state()
	_set_physics_active(false)


func focus_prompt(player: WizardPlayer, _collider: Object) -> String:
	if player == null or player.hands == null:
		return ""
	if player.hands.held_item == null:
		return "Pick up %s" % get_display_name()
	return "Empty your hands"


func interact(player: WizardPlayer, _collider: Object) -> void:
	if player == null or player.hands == null:
		return
	if player.hands.held_item != null:
		return
	player.hands.pick_up(self)


func get_display_name() -> String:
	if book_data != null:
		return book_data.get_display_name()
	return "Untitled Book"


func get_held_hint() -> String:
	if _is_reading:
		return "%s  [Arrows pages / LMB close / G drop]" % get_display_name()
	return "%s  [LMB read / G drop]" % get_display_name()


func get_held_pose() -> Dictionary:
	return {
		"position": held_position,
		"rotation": held_rotation,
		"scale": held_scale,
	}


func set_held(value: bool) -> void:
	_is_held = value
	if _is_held:
		_is_stationed = false
		_is_reference_open = false
		_reference_page_turn_enabled = false
	if _is_held:
		_close_reading(false)
		_set_physics_active(false)
	else:
		_close_reading(true)
		_set_physics_active(true)
	_refresh_model_state()


func set_stationed(value: bool) -> void:
	_is_stationed = value
	if _is_stationed:
		_is_held = false
		_close_reading(false)
		_set_physics_active(false)
	else:
		_is_reference_open = false
		_reference_page_turn_enabled = false
		if not _is_held:
			_set_physics_active(true)
	_refresh_model_state()


func cast_from(caster: Node, _camera_transform: Transform3D) -> String:
	if not _is_held:
		return ""
	if _is_reading:
		_close_reading(true)
		return "Closed %s." % get_display_name()
	_open_reading(caster as WizardPlayer)
	return "Opened %s." % get_display_name()


func open_for_reference() -> void:
	_is_reference_open = true
	_is_reading = false
	_update_page_content()
	_refresh_model_state()


func set_reference_page_turn_enabled(value: bool) -> void:
	_reference_page_turn_enabled = value


func has_loaded_rune_template() -> bool:
	return book_data != null and book_data.has_rune_template()


func _input(event: InputEvent) -> void:
	if not _is_reading and not (_is_stationed and _is_reference_open and _reference_page_turn_enabled):
		return
	if event.is_action_pressed("ui_cancel"):
		if _is_reading:
			_close_reading(true)
			get_viewport().set_input_as_handled()
	elif _previous_page_pressed(event):
		_previous_page()
		get_viewport().set_input_as_handled()
	elif _next_page_pressed(event):
		_next_page()
		get_viewport().set_input_as_handled()


func _open_reading(reader: WizardPlayer) -> void:
	_is_reading = true
	_reader = reader
	_move_to_reading_pose()
	_update_page_content()
	_refresh_model_state()


func _close_reading(_restore_controls: bool) -> void:
	var was_reading := _is_reading
	_reader = null
	_is_reading = false
	if _is_held and was_reading:
		_move_to_held_pose()
	_refresh_model_state()


func _previous_page_pressed(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_left"):
		return true
	return not _is_reading and event.is_action_pressed("move_left")


func _next_page_pressed(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_right"):
		return true
	return not _is_reading and event.is_action_pressed("move_right")


func _cache_page_nodes() -> void:
	_held_page_content = get_node_or_null(held_page_content_path) as Node3D
	_held_page_surface = get_node_or_null(held_page_surface_path) as MeshInstance3D
	_table_page_content = get_node_or_null(table_page_content_path) as Node3D
	_table_page_surface = get_node_or_null(table_page_surface_path) as MeshInstance3D
	_page_viewport = get_node_or_null(page_viewport_path) as SubViewport
	_left_title_label = get_node_or_null(left_title_label_path) as Label
	_left_body_label = get_node_or_null(left_body_label_path) as Label
	_left_rune_view = get_node_or_null(left_rune_view_path) as Control
	_right_title_label = get_node_or_null(right_title_label_path) as Label
	_right_body_label = get_node_or_null(right_body_label_path) as Label
	_right_rune_view = get_node_or_null(right_rune_view_path) as Control
	_footer_label = get_node_or_null(footer_label_path) as Label


func _apply_page_viewport_to_surface() -> void:
	if _page_viewport == null:
		return
	for surface in _page_surfaces():
		var material := StandardMaterial3D.new()
		material.resource_local_to_scene = true
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_texture = _page_viewport.get_texture()
		material.uv1_scale = Vector3(
			-1.0 if flip_page_texture_horizontal else 1.0,
			-1.0 if flip_page_texture_vertical else 1.0,
			1.0
		)
		material.uv1_offset = Vector3(
			1.0 if flip_page_texture_horizontal else 0.0,
			1.0 if flip_page_texture_vertical else 0.0,
			0.0
		)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		surface.material_override = material


func _update_page_content() -> void:
	var spread_count := _spread_count()
	current_page = clampi(current_page, 0, maxi(spread_count - 1, 0))
	var spread := _current_spread()
	var left_page := spread.left_page if spread != null else null
	var right_page := spread.right_page if spread != null else null
	_apply_page_to_view(left_page, _left_title_label, _left_body_label, _left_rune_view)
	_apply_page_to_view(right_page, _right_title_label, _right_body_label, _right_rune_view)
	if _footer_label != null:
		_footer_label.text = _page_range_text(spread_count)
	_update_rune_playback_state()


func _next_page() -> void:
	var count := _spread_count()
	if count <= 1:
		return
	current_page = mini(current_page + 1, count - 1)
	_update_page_content()


func _previous_page() -> void:
	if current_page <= 0:
		return
	current_page -= 1
	_update_page_content()


func _apply_page_to_view(page: BookPageData, title_label: Label, body_label: Label, rune_view: Control) -> void:
	if title_label != null:
		title_label.text = page.title if page != null else ""
	if body_label != null:
		body_label.text = page.body if page != null else ""
	if rune_view == null:
		return
	var show_rune := page != null and page.rune_template != null and page.show_rune_playback
	rune_view.visible = show_rune
	if rune_view.has_method("set_strokes"):
		var strokes: Array[PackedVector2Array] = []
		if show_rune:
			strokes = page.rune_template.get_stroke_snapshot()
		rune_view.call("set_strokes", strokes)


func _spread_count() -> int:
	if book_data == null:
		return 1
	return maxi(book_data.get_spread_count(), 1)


func _current_spread() -> BookSpreadData:
	if book_data == null or book_data.get_spread_count() <= 0:
		return _blank_spread()
	return book_data.get_spread(current_page)


func _blank_spread() -> BookSpreadData:
	var left := BookPageData.new()
	left.title = get_display_name()
	left.body = "The pages are blank."
	var right := BookPageData.new()
	var spread := BookSpreadData.new()
	spread.left_page = left
	spread.right_page = right
	return spread


func _page_range_text(spread_count: int) -> String:
	if spread_count <= 1:
		return "Spread 1"
	return "Spread %d of %d" % [current_page + 1, spread_count]


func _move_to_reading_pose() -> void:
	_tween_held_transform(reading_position, reading_rotation, reading_scale)


func _move_to_held_pose() -> void:
	_tween_held_transform(held_position, held_rotation, held_scale)


func _tween_held_transform(target_position: Vector3, target_rotation: Vector3, target_scale: Vector3) -> void:
	if _pose_tween and _pose_tween.is_valid():
		_pose_tween.kill()
	if not is_inside_tree():
		position = target_position
		rotation = target_rotation
		scale = target_scale
		return
	_pose_tween = create_tween()
	_pose_tween.tween_property(self, "position", target_position, reading_pose_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose_tween.parallel().tween_property(self, "rotation", target_rotation, reading_pose_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose_tween.parallel().tween_property(self, "scale", target_scale, reading_pose_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _refresh_model_state() -> void:
	var held_open := _is_reading
	var table_open := _is_reference_open
	var open := held_open or table_open
	if _closed_model != null:
		_closed_model.visible = not open
	if _held_open_model != null:
		_held_open_model.visible = held_open
	if _table_open_model != null:
		_table_open_model.visible = table_open
	if _held_page_content != null:
		_held_page_content.visible = held_open
	if _held_page_surface != null:
		_held_page_surface.visible = held_open
	if _table_page_content != null:
		_table_page_content.visible = table_open
	if _table_page_surface != null:
		_table_page_surface.visible = table_open
	_update_rune_playback_state()


func _page_surfaces() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if _held_page_surface != null:
		out.append(_held_page_surface)
	if _table_page_surface != null:
		out.append(_table_page_surface)
	return out


func _set_physics_active(active: bool) -> void:
	freeze = not active
	sleeping = not active
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = active_collision_layer if active or _is_stationed or not _is_held else 0
	collision_mask = active_collision_mask if active or _is_stationed or not _is_held else 0


func _update_rune_playback_state() -> void:
	var any_playing := false
	var spread := _current_spread()
	any_playing = _update_rune_view_playback(_left_rune_view, spread.left_page if spread != null else null) or any_playing
	any_playing = _update_rune_view_playback(_right_rune_view, spread.right_page if spread != null else null) or any_playing
	if _page_viewport != null:
		_page_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if any_playing else SubViewport.UPDATE_ONCE


func _update_rune_view_playback(rune_view: Control, page: BookPageData) -> bool:
	var should_play := autoplay_rune_stroke_playback \
		and (_is_reading or _is_reference_open) \
		and page != null \
		and page.rune_template != null \
		and page.show_rune_playback
	if rune_view != null \
			and rune_view.has_method("restart_playback") \
			and rune_view.has_method("stop_playback") \
			and rune_view.has_method("is_playback_active"):
		if should_play:
			if not bool(rune_view.call("is_playback_active")):
				rune_view.call("restart_playback")
		else:
			rune_view.call("stop_playback", true)
	return should_play
