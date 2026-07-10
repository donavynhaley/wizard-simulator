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

@export var book_title := "Untitled Book"
@export var pages: Array[String] = []
@export_group("Page Content")
@export_node_path("Node3D") var page_content_path: NodePath = ^"PageContent"
@export_node_path("MeshInstance3D") var page_surface_path: NodePath = ^"PageContent/PageSurface"
@export_node_path("SubViewport") var page_viewport_path: NodePath = ^"BookPageViewport"
@export_node_path("Label") var left_title_label_path: NodePath = ^"BookPageViewport/SpreadRoot/Pages/LeftPage/Margin/LeftColumn/Title"
@export_node_path("Label") var left_body_label_path: NodePath = ^"BookPageViewport/SpreadRoot/Pages/LeftPage/Margin/LeftColumn/Body"
@export_node_path("Label") var right_title_label_path: NodePath = ^"BookPageViewport/SpreadRoot/Pages/RightPage/Margin/RightColumn/Title"
@export_node_path("Label") var right_body_label_path: NodePath = ^"BookPageViewport/SpreadRoot/Pages/RightPage/Margin/RightColumn/Body"
@export_node_path("Label") var footer_label_path: NodePath = ^"BookPageViewport/SpreadRoot/Footer"
@export_node_path("Control") var rune_view_path: NodePath = ^"BookPageViewport/SpreadRoot/Pages/RightPage/Margin/RightColumn/RuneView"
@export_group("Rune Book")
@export var is_rune_book := false
@export var rune_id := ""
@export_dir var rune_template_directory := "res://data/runes/templates"
@export var autoplay_rune_stroke_playback := true
@export_group("Held Pose")
@export var held_position := Vector3(0.02, -0.02, -0.18)
@export var held_rotation := Vector3(-0.78, 0.0, 0.0)
@export var held_scale := Vector3.ONE
@export_group("Reading Pose")
@export var reading_position := Vector3(-0.18, -0.08, -0.36)
@export var reading_rotation := Vector3(-1.08, 0.0, PI)
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
var _page_content: Node3D
var _page_surface: MeshInstance3D
var _page_viewport: SubViewport
var _left_title_label: Label
var _left_body_label: Label
var _right_title_label: Label
var _right_body_label: Label
var _footer_label: Label
var _rune_view: Control
var _closed_model: Node3D
var _open_model: Node3D
var _template: Resource
var _pose_tween: Tween


func _ready() -> void:
	_closed_model = get_node_or_null("book_closed") as Node3D
	_open_model = get_node_or_null("book_open") as Node3D
	_cache_page_nodes()
	_apply_page_viewport_to_surface()
	_load_rune_template()
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
	if is_rune_book and not _rune_display_name().is_empty():
		return "%s Rune Book" % _rune_display_name()
	return book_title


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
	_refresh_model_state(true)


func set_reference_page_turn_enabled(value: bool) -> void:
	_reference_page_turn_enabled = value


func has_loaded_rune_template() -> bool:
	return not _template_strokes().is_empty()


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
	_refresh_model_state(true)


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
	_page_content = get_node_or_null(page_content_path) as Node3D
	_page_surface = get_node_or_null(page_surface_path) as MeshInstance3D
	_page_viewport = get_node_or_null(page_viewport_path) as SubViewport
	_left_title_label = get_node_or_null(left_title_label_path) as Label
	_left_body_label = get_node_or_null(left_body_label_path) as Label
	_right_title_label = get_node_or_null(right_title_label_path) as Label
	_right_body_label = get_node_or_null(right_body_label_path) as Label
	_footer_label = get_node_or_null(footer_label_path) as Label
	_rune_view = get_node_or_null(rune_view_path) as Control


func _apply_page_viewport_to_surface() -> void:
	if _page_surface == null or _page_viewport == null:
		return
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _page_viewport.get_texture()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_page_surface.material_override = material


func _update_page_content() -> void:
	var all_pages := _page_texts()
	current_page = clampi(current_page, 0, maxi(all_pages.size() - 1, 0))
	var left_text := all_pages[current_page] if not all_pages.is_empty() else ""
	var right_index := current_page + 1
	var right_text := all_pages[right_index] if right_index < all_pages.size() else ""
	if _left_title_label != null:
		_left_title_label.text = get_display_name()
	if _left_body_label != null:
		_left_body_label.text = left_text
	if _right_title_label != null:
		_right_title_label.text = _rune_display_name() if is_rune_book else ""
	if _right_body_label != null:
		_right_body_label.text = _rune_reference_text() if is_rune_book else right_text
	if _footer_label != null:
		_footer_label.text = _page_range_text(all_pages.size())
	if _rune_view != null:
		_rune_view.visible = is_rune_book and _template != null
		_rune_view.set_strokes(_template_strokes())
	_update_rune_playback_state()


func _next_page() -> void:
	var count := _page_texts().size()
	if count <= 1:
		return
	current_page = mini(current_page + 1, count - 1)
	_update_page_content()


func _previous_page() -> void:
	if current_page <= 0:
		return
	current_page -= 1
	_update_page_content()


func _page_texts() -> Array[String]:
	var out: Array[String] = []
	for page in pages:
		if not page.strip_edges().is_empty():
			out.append(page)
	if is_rune_book:
		var rune_name := _rune_display_name()
		var category := _rune_category()
		out.push_front("%s rune\nCategory: %s\nTrace the strokes shown above in order on the %s section of the scroll." % [
			rune_name if not rune_name.is_empty() else rune_id.capitalize(),
			category.capitalize(),
			category,
		])
	if out.is_empty():
		out.append("The pages are blank.")
	return out


func _rune_reference_text() -> String:
	if not is_rune_book:
		return ""
	var category := _rune_category()
	return "Category: %s\n\nWatch the glowing tip, then copy each stroke in order." % category.capitalize()


func _page_range_text(page_count: int) -> String:
	if page_count <= 1:
		return "Page 1"
	var right_page := mini(current_page + 2, page_count)
	return "Pages %d-%d of %d" % [current_page + 1, right_page, page_count]


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


func _load_rune_template() -> void:
	_template = null
	if not is_rune_book or rune_id.strip_edges().is_empty():
		return
	var directory := "%s/%s" % [rune_template_directory.trim_suffix("/"), rune_id.strip_edges().to_lower()]
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			var resource := ResourceLoader.load("%s/%s" % [directory, file_name])
			if resource != null and String(resource.get("rune_id")) == rune_id:
				_template = resource
				break
		file_name = dir.get_next()
	dir.list_dir_end()


func _template_strokes() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if _template == null:
		return out
	var value: Variant = _template.get("strokes")
	if value is Array:
		for stroke in value:
			if stroke is PackedVector2Array:
				out.append(PackedVector2Array(stroke))
	return out


func _rune_display_name() -> String:
	if _template == null:
		return rune_id.capitalize()
	var value: Variant = _template.get("display_name")
	if value is String and not String(value).is_empty():
		return value as String
	return rune_id.capitalize()


func _rune_category() -> String:
	if _template == null:
		return "rune"
	var value: Variant = _template.get("category")
	if value is String and not String(value).is_empty():
		return value as String
	return "rune"


func _refresh_model_state(force_open: bool = false) -> void:
	var open := force_open or _is_reading or _is_reference_open
	if _closed_model != null:
		_closed_model.visible = not open
	if _open_model != null:
		_open_model.visible = open
	if _page_content != null:
		_page_content.visible = open
	_update_rune_playback_state()


func _set_physics_active(active: bool) -> void:
	freeze = not active
	sleeping = not active
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = active_collision_layer if active or _is_stationed or not _is_held else 0
	collision_mask = active_collision_mask if active or _is_stationed or not _is_held else 0


func _update_rune_playback_state() -> void:
	var should_play := autoplay_rune_stroke_playback \
		and is_rune_book \
		and _template != null \
		and (_is_reading or _is_reference_open)
	if _rune_view != null \
			and _rune_view.has_method("restart_playback") \
			and _rune_view.has_method("stop_playback") \
			and _rune_view.has_method("is_playback_active"):
		if should_play:
			if not bool(_rune_view.call("is_playback_active")):
				_rune_view.call("restart_playback")
		else:
			_rune_view.call("stop_playback", true)
	if _page_viewport != null:
		_page_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if should_play else SubViewport.UPDATE_ONCE
