class_name Book
extends Item

## A physical book whose interaction, visual model, and rendered pages are
## composed as separate scenes.

signal page_changed(spread_index: int)
signal page_turn_started(from_spread: int, to_spread: int)
signal reading_finished(book: Book)

@export var book_data: BookData:
	set(value):
		book_data = value
		if is_node_ready():
			_apply_visual_profile()
			_update_page_content()

@export_group("Composed Scenes")
@export_node_path("BookVisual") var visual_path: NodePath = ^"Visual"
@export_node_path("BookPageRenderer") var page_renderer_path: NodePath = ^"PageRenderer"

@export_group("Held Root Pose")
@export var held_position := Vector3.ZERO
@export var held_rotation := Vector3.ZERO
@export var held_scale := Vector3.ONE

@export_group("Physics")
@export_flags_3d_physics var active_collision_layer: int = 2
@export_flags_3d_physics var active_collision_mask: int = 1

var current_page := 0

var _is_held := false
var _is_stationed := false
var _is_reference_open := false
var _reference_page_turn_enabled := false
var _is_reading := false
var _page_turning := false
var _pending_page := -1
var _page_turn_generation := 0
var _visual: BookVisual
var _page_renderer: BookPageRenderer


func _ready() -> void:
	_visual = get_node_or_null(visual_path) as BookVisual
	_page_renderer = get_node_or_null(page_renderer_path) as BookPageRenderer
	if _visual != null:
		_visual.page_turn_midpoint_reached.connect(_on_page_turn_midpoint)
		_visual.page_turn_finished.connect(_on_page_turn_finished)
	_apply_visual_profile()
	if _visual != null and _page_renderer != null:
		_visual.set_page_texture(_page_renderer.get_texture())
	_update_page_content()
	_refresh_visual_state()
	_set_physics_active(false)


func get_display_name() -> String:
	return book_data.get_display_name() if book_data != null else "Untitled Book"


func get_held_pose() -> Dictionary:
	return {
		"position": held_position,
		"rotation": held_rotation,
		"scale": held_scale,
	}


func is_reading() -> bool:
	return _is_reading


func set_held(value: bool) -> void:
	var was_reading := _is_reading
	if was_reading:
		_set_close_focus(false)
	_is_held = value
	if _is_held:
		_is_stationed = false
		_is_reference_open = false
		_reference_page_turn_enabled = false
		_is_reading = false
		_cancel_page_turn()
		_set_physics_active(false)
	else:
		_is_reading = false
		_cancel_page_turn()
		_set_physics_active(true)
	_refresh_visual_state()
	if was_reading and not _is_reading:
		reading_finished.emit(self)


func set_stationed(value: bool) -> void:
	var was_reading := _is_reading
	if was_reading:
		_set_close_focus(false)
	_is_stationed = value
	if _is_stationed:
		_is_held = false
		_is_reading = false
		_cancel_page_turn()
		_set_physics_active(false)
	else:
		_is_reference_open = false
		_reference_page_turn_enabled = false
		_cancel_page_turn()
		if not _is_held:
			_set_physics_active(true)
	_refresh_visual_state()
	if was_reading and not _is_reading:
		reading_finished.emit(self)


func cast_from(_caster: Node, _camera_transform: Transform3D) -> String:
	if not _is_held:
		return ""
	if _is_reading:
		_close_reading()
		return "Closed %s." % get_display_name()
	_open_reading()
	return "Opened %s." % get_display_name()


func open_for_reference() -> void:
	var was_reading := _is_reading
	if was_reading:
		_set_close_focus(false)
	_is_reference_open = true
	_is_reading = false
	_cancel_page_turn()
	_update_page_content()
	_refresh_visual_state()
	if was_reading:
		reading_finished.emit(self)


func set_reference_page_turn_enabled(value: bool) -> void:
	_reference_page_turn_enabled = value


func has_loaded_rune_template() -> bool:
	return book_data != null and book_data.has_rune_template()


func is_page_turning() -> bool:
	return _page_turning


## Jumps straight to a spread without the page-turn animation. Intended for
## initialization and other state changes that should not animate.
func jump_to_spread(index: int) -> void:
	_cancel_page_turn()
	current_page = clampi(index, 0, _spread_count() - 1)
	_update_page_content()
	page_changed.emit(current_page)


## Turns toward an arbitrary spread using the physical page animation. This
## is used by bookmark navigation, while jump_to_spread remains available for
## initialization and other intentionally immediate state changes.
func turn_to_spread(index: int) -> void:
	var target := clampi(index, 0, _spread_count() - 1)
	if target == current_page or _page_turning:
		return
	_start_page_turn(target, 1 if target > current_page else -1)


## Bookmark ribbon tabs rendered on the page edge (see BookPageRenderer).
func set_bookmarks(names: Array[String], active_index: int) -> void:
	if _page_renderer != null:
		_page_renderer.set_bookmarks(names, active_index)


## Maps a main-viewport mouse position onto the rendered two-page spread.
## Values outside the spread return (-1, -1).
func page_uv_from_screen(camera: Camera3D, screen_position: Vector2) -> Vector2:
	if _visual == null:
		return Vector2(-1.0, -1.0)
	return _visual.page_uv_from_screen(camera, screen_position)


## Projects a normalized point on the spread back to the main viewport.
func page_uv_to_screen(camera: Camera3D, page_uv: Vector2) -> Vector2:
	if _visual == null:
		return Vector2(-1.0, -1.0)
	return _visual.page_uv_to_screen(camera, page_uv)


func bookmark_at_page_uv(page_uv: Vector2) -> int:
	if _page_renderer == null:
		return -1
	return _page_renderer.bookmark_at_page_uv(page_uv)


func _input(event: InputEvent) -> void:
	if _is_reading and event.is_action_pressed(&"book_focus"):
		_set_close_focus(true)
		get_viewport().set_input_as_handled()
		return
	if _is_reading and event.is_action_released(&"book_focus"):
		_set_close_focus(false)
		get_viewport().set_input_as_handled()
		return
	if _page_turning:
		return
	if not _is_reading and not (_is_stationed and _is_reference_open and _reference_page_turn_enabled):
		return
	if event.is_action_pressed("ui_cancel"):
		if _is_reading:
			_close_reading()
			get_viewport().set_input_as_handled()
	elif _previous_page_pressed(event):
		_previous_page()
		get_viewport().set_input_as_handled()
	elif _next_page_pressed(event):
		_next_page()
		get_viewport().set_input_as_handled()


func _open_reading() -> void:
	_is_reading = true
	_update_page_content()
	_refresh_visual_state()


func _close_reading() -> void:
	if not _is_reading:
		return
	_set_close_focus(false)
	_is_reading = false
	_cancel_page_turn()
	if _page_renderer != null:
		_page_renderer.set_rendering_active(_is_reference_open)
	if _visual != null and _is_held:
		_visual.close_held()
	else:
		_refresh_visual_state()
	reading_finished.emit(self)


func _set_close_focus(enabled: bool) -> void:
	if _visual == null or _visual.is_close_focused() == enabled:
		return
	_visual.set_close_focus(enabled)


func _previous_page_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_left") \
		or event.is_action_pressed("move_left")


func _next_page_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_right") \
		or event.is_action_pressed("move_right")


func _update_page_content() -> void:
	var spread_count := _spread_count()
	current_page = clampi(current_page, 0, maxi(spread_count - 1, 0))
	if _visual != null:
		_visual.set_page_progress(current_page, spread_count)
	if _page_renderer != null:
		_page_renderer.show_spread(book_data, get_display_name(), current_page)


func _apply_visual_profile() -> void:
	if _visual == null:
		return
	var profile := book_data.visual_profile if book_data != null else null
	_visual.apply_profile(profile)


func _next_page() -> void:
	var target := mini(current_page + 1, _spread_count() - 1)
	if target == current_page:
		return
	_start_page_turn(target, 1)


func _previous_page() -> void:
	var target := maxi(current_page - 1, 0)
	if target == current_page:
		return
	_start_page_turn(target, -1)


func _start_page_turn(target_page: int, direction: int) -> void:
	if _page_turning:
		return
	_page_turning = true
	_pending_page = target_page
	_page_turn_generation += 1
	var generation := _page_turn_generation
	var outgoing_texture: Texture2D
	if _page_renderer != null:
		_page_renderer.set_rune_playback_enabled(false)
		outgoing_texture = _page_renderer.capture_snapshot()
		_page_renderer.show_spread(book_data, get_display_name(), target_page)
	page_turn_started.emit(current_page, target_page)
	_begin_prepared_page_turn(direction, generation, outgoing_texture)


func _begin_prepared_page_turn(
		direction: int,
		generation: int,
		outgoing_texture: Texture2D) -> void:
	# SubViewport.UPDATE_ONCE draws after the process step. Waiting one full
	# frame gives the destination page a complete texture before the outgoing
	# sheet lifts away, and also works with Godot's headless dummy renderer.
	await get_tree().process_frame
	if not is_instance_valid(self) \
			or generation != _page_turn_generation \
			or not _page_turning:
		return
	# Keep the destination on its live viewport texture for the whole turn.
	# Using a snapshot here required a visible snapshot-to-viewport handoff when
	# the sheet landed, especially once rune playback resumed.
	var destination_texture: Texture2D = _page_renderer.get_texture() \
		if is_instance_valid(_page_renderer) else null
	var spread_count := _spread_count()
	var destination_progress_ratio := 0.5 if spread_count <= 1 else clampf(
		float(_pending_page) / float(spread_count - 1), 0.0, 1.0)
	if not is_instance_valid(_visual) or not _visual.play_page_turn(
			direction,
			outgoing_texture,
			destination_texture,
			destination_progress_ratio):
		_on_page_turn_midpoint()
		_on_page_turn_finished()


func _on_page_turn_midpoint() -> void:
	if not _page_turning or _pending_page < 0:
		return
	current_page = _pending_page
	if _visual != null:
		_visual.set_page_progress(current_page, _spread_count())
	page_changed.emit(current_page)


func _on_page_turn_finished() -> void:
	if not _page_turning:
		return
	if current_page != _pending_page:
		_on_page_turn_midpoint()
	_pending_page = -1
	_page_turning = false
	if _page_renderer != null:
		_page_renderer.set_rune_playback_enabled(true)


func _cancel_page_turn() -> void:
	_page_turn_generation += 1
	_pending_page = -1
	_page_turning = false
	if _visual != null:
		_visual.cancel_page_turn()
	if _page_renderer != null:
		_page_renderer.set_rune_playback_enabled(true)
		_page_renderer.show_spread(book_data, get_display_name(), current_page)


func _spread_count() -> int:
	return maxi(book_data.get_spread_count(), 1) if book_data != null else 1


func _refresh_visual_state() -> void:
	var pages_visible := _is_reading or _is_reference_open
	if _page_renderer != null:
		_page_renderer.set_rendering_active(pages_visible)
	if _visual == null:
		return
	if _is_reading:
		_visual.open_held()
	elif _is_reference_open:
		_visual.show_table_open()
	elif _is_held:
		_visual.show_held_closed()
	else:
		_visual.show_world_closed()


func _set_physics_active(active: bool) -> void:
	freeze = not active
	sleeping = not active
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = active_collision_layer if active or _is_stationed or not _is_held else 0
	collision_mask = active_collision_mask if active or _is_stationed or not _is_held else 0

