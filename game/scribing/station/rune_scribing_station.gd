extends Node3D

## Scribing station on the crafting table. Interacting with empty hands takes
## over the camera (ScribeCamera), locks the player through
## WizardPlayer.set_control_enabled(), and lets the player draw strokes onto
## the scroll via a ScribeCanvas rendered to a SubViewport.

signal scribing_started
signal scribing_completed(stroke_count: int)
signal scribing_cancelled
signal rune_recognized(result: Resource)
signal rune_rejected(result: Resource)

const RuneRecognizerResource := preload("res://game/scribing/runes/rune_recognizer.gd")
const ScribingSessionState := preload("res://game/scribing/session/scribing_session.gd")

@export var prompt_text: String = "Begin scribing"
@export var active_prompt: String = "Scribing - W book / S scroll / hold Space to seal"
@export var sealed_prompt: String = "Runes sealed"

@export_group("Scribing")
## Input action the player holds to seal the scribed runes after drawing at least one mark.
@export var seal_action: StringName = &"jump"
## Seconds the seal action must be held before the runes are sealed.
@export var seal_hold_time: float = 0.8
## Width of the physical ink mesh drawn back onto the table scroll.
@export var ink_width: float = 0.007
## Small vertical offset that keeps physical ink from z-fighting with the scroll.
@export var ink_lift: float = 0.001
## Pixel size of the render texture that is projected onto the scroll surface.
@export var scribe_texture_size := Vector2i(1024, 768)
## Physical width and height of the projected ink plane in meters.
## Leave either component at 0 to derive both dimensions from the scroll.
@export var scribe_surface_size_m: Vector2 = Vector2.ZERO
## Clockwise rotation of the projected ink plane around the scroll's surface normal.
@export_range(-180.0, 180.0, 1.0) var scribe_surface_rotation_degrees: float = 0.0
## Draws the scroll's millimeter ruler/grid into the projected scribe texture.
@export var show_scroll_measurements: bool = true
## Major ruler interval in millimeters.
@export var measurement_major_tick_mm: float = 50.0
## Minor ruler interval in millimeters.
@export var measurement_minor_tick_mm: float = 10.0

@export_group("Rune Recognition")
@export_dir var rune_template_directory: String = "res://content/runes/templates"
@export var load_rune_templates_on_ready: bool = true

@export_group("Reference Book")
@export_node_path("Node3D") var reference_book_placement_path: NodePath = ^"../OpenBookPlacement"

@export_group("Table Camera")
@export_multiline var table_camera_notes := "Scribing requires this Camera3D. Move, rotate, and tune its FOV directly in the crafting table scene for exact composition."
## Required Camera3D in the crafting table scene. Move this camera in the editor for exact scribing composition.
@export_node_path("Camera3D") var scribe_camera_path: NodePath = ^"ScribeCamera"
## Camera pose used while drawing on the scroll. Author this marker in the crafting table scene.
@export_node_path("Marker3D") var scroll_camera_pose_path: NodePath = ^"ScrollCameraPose"
## Camera pose used while referring back to the open rune book. Author this marker in the crafting table scene.
@export_node_path("Marker3D") var book_camera_pose_path: NodePath = ^"BookCameraPose"
## Seconds used to ease between the scroll and reference-book camera poses.
@export_range(0.05, 1.0, 0.01) var camera_transition_time: float = 0.28

@export_group("Scribe Props")
## Root of the authored quill prop that moves during scribing.
@export_node_path("Node3D") var quill_path: NodePath = ^"Quill"
## Marker authored at the nib of the imported quill model.
@export_node_path("Marker3D") var quill_tip_path: NodePath = ^"Quill/WritingTip"
## Scene-authored orientation used while the quill follows the scroll cursor.
@export_node_path("Marker3D") var quill_scribe_pose_path: NodePath = ^"QuillScribePose"
## 0 locks directly to the mouse. Higher values add catch-up smoothing.
@export var prop_follow_speed: float = 0.0
## How far above the scroll surface the quill body rides while the tip follows the cursor.
@export var quill_hover_lift: float = 0.002

@onready var scroll: Node3D = $Scroll
@onready var quill: Node3D = get_node_or_null(quill_path) as Node3D
@onready var quill_tip: Marker3D = get_node_or_null(quill_tip_path) as Marker3D
@onready var quill_scribe_pose: Marker3D = (
	get_node_or_null(quill_scribe_pose_path) as Marker3D)

var _active := false
var _sealed := false
var _player: WizardPlayer
var _original_camera: Camera3D
var _scribe_camera: Camera3D
var _scroll_camera_pose: Marker3D
var _book_camera_pose: Marker3D
var _camera_tween: Tween
var _scribe_viewport: SubViewport
var _scribe_surface: MeshInstance3D
var _scribe_canvas: ScribeCanvas
var _rune_recognizer: Resource
var _session: ScribingSession = ScribingSessionState.new()
var _reference_book: Book
var _seal_hold_elapsed := 0.0
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _reference_book_placement: OpenBookPlacement
var _quill_rest_transform := Transform3D.IDENTITY
var _last_cursor_point := Vector2(0.5, 0.5)
var _has_cursor_point := false


func _ready() -> void:
	_reference_book_placement = get_node_or_null(reference_book_placement_path) as OpenBookPlacement
	_scroll_camera_pose = get_node_or_null(scroll_camera_pose_path) as Marker3D
	_book_camera_pose = get_node_or_null(book_camera_pose_path) as Marker3D
	if _reference_book_placement != null:
		_reference_book_placement.book_placed.connect(_on_reference_book_placed)
		_reference_book_placement.book_taken.connect(_on_reference_book_taken)
	_configure_rune_recognizer()
	if quill:
		_quill_rest_transform = quill.transform
	_create_scribe_surface()
	if quill == null:
		push_error("RuneScribingStation requires an authored quill at quill_path.")
	elif quill_tip == null:
		push_error("RuneScribingStation requires a WritingTip marker on its quill.")
	if quill_scribe_pose == null:
		push_error("RuneScribingStation requires a scene-authored QuillScribePose marker.")


func interact(player: WizardPlayer, _collider: Object) -> void:
	if _active:
		return
	if _sealed:
		WizardHud.toast(self, sealed_prompt)
		return

	if player == null:
		return

	_begin_scribing(player)


func focus_prompt(player: WizardPlayer, _collider: Object) -> String:
	if _active:
		return ""
	if _sealed:
		return sealed_prompt

	if player == null:
		return ""
	return prompt_text


func _on_reference_book_placed(book: Book) -> void:
	_reference_book = book


func _on_reference_book_taken(book: Book) -> void:
	if _reference_book == book:
		_reference_book = null


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		_end_scribing(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"move_forward"):
		_move_scribe_camera_to_pose(_book_camera_pose)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"move_backward"):
		_move_scribe_camera_to_pose(_scroll_camera_pose)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_LEFT:
			var point: Variant = _scroll_point_from_screen(button_event.position)
			if button_event.pressed and point != null:
				var stroke_point := point as Vector2
				var category := _scribe_canvas.category_for_point(stroke_point)
				if _scribe_canvas.is_category_recognized(category):
					WizardHud.toast(self, "%s rune already set" % category.capitalize())
				else:
					_scribe_canvas.begin_surface_stroke(stroke_point)
					_set_cursor_point(stroke_point)
				get_viewport().set_input_as_handled()
			elif not button_event.pressed:
				_scribe_canvas.end_surface_stroke()
				_try_auto_recognize_category(_scribe_canvas.get_last_stroke_category())
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var point: Variant = _scroll_point_from_screen(motion.position)
		if point != null:
			_set_cursor_point(point as Vector2)
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_scribe_canvas.append_surface_point(point as Vector2)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _active or _scribe_canvas == null:
		return

	var point: Variant = _scroll_point_from_screen(get_viewport().get_mouse_position())
	if point != null:
		_set_cursor_point(point as Vector2)
	_update_scribe_props(delta)

	if (_scribe_canvas.has_ink() or _session.has_recognized_runes()) and Input.is_action_pressed(seal_action):
		_seal_hold_elapsed = minf(_seal_hold_elapsed + delta, seal_hold_time)
		_scribe_canvas.seal_hold_progress = _seal_hold_elapsed / maxf(seal_hold_time, 0.001)
		if _seal_hold_elapsed >= seal_hold_time:
			_end_scribing(true, max(_session.recognized_rune_count(), _scribe_canvas.strokes.size()))
	else:
		_seal_hold_elapsed = 0.0
		_scribe_canvas.seal_hold_progress = 0.0


func _try_auto_recognize_category(category: String) -> Resource:
	if _scribe_canvas == null or not _scribe_canvas.has_ink():
		return null
	if category.is_empty() or _scribe_canvas.is_category_recognized(category):
		return null
	if _rune_recognizer == null:
		WizardHud.toast(self, "Rune recognizer is unavailable")
		return null
	if _rune_recognizer.get("rune_definitions").is_empty():
		WizardHud.toast(self, "No rune templates recorded")
		return null

	_scribe_canvas.end_surface_stroke()
	var category_strokes := _scribe_canvas.get_strokes_for_category(category)
	var result := _rune_recognizer.call("recognize", category_strokes, category) as Resource
	if result == null:
		WizardHud.toast(self, "Rune did not resolve")
		return null

	if bool(result.call("is_match")):
		_session.record_recognition(
			category,
			result.get("rune") as Resource,
			float(result.get("confidence")))
		_scribe_canvas.mark_category_recognized(category)
		WizardHud.toast(self, "%s recognized (%d%%)" % [
			_result_rune_name(result),
			int(roundf(float(result.get("confidence")) * 100.0)),
		])
		rune_recognized.emit(result)
	else:
		WizardHud.toast(self, "Unknown rune (%d%%)" % int(roundf(float(result.get("confidence")) * 100.0)))
		rune_rejected.emit(result)
	return result


func get_recognized_rune_ids() -> Array[StringName]:
	return _session.recognized_rune_ids(_scribe_canvas.get_segment_categories())


func get_rune_qualities() -> Array[float]:
	return _session.rune_qualities(_scribe_canvas.get_segment_categories())


func _begin_scribing(player: WizardPlayer) -> void:
	_active = true
	_player = player
	_session.reset_recognition()
	_seal_hold_elapsed = 0.0
	_previous_mouse_mode = Input.mouse_mode
	_original_camera = get_viewport().get_camera_3d()
	_last_cursor_point = Vector2(0.5, 0.5)
	_has_cursor_point = true

	if not _activate_scribe_camera():
		_active = false
		return
	player.set_control_enabled(false)
	_create_scribe_surface()
	_update_scribe_props(1.0)
	if _reference_book != null:
		_reference_book.set_reference_page_turn_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	scribing_started.emit()


func _end_scribing(completed: bool, stroke_count: int = 0) -> void:
	if not _active:
		return

	_active = false
	if _reference_book != null:
		_reference_book.set_reference_page_turn_enabled(false)
	if _original_camera and is_instance_valid(_original_camera):
		_original_camera.make_current()

	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = null
	_scribe_camera = null
	Input.mouse_mode = _previous_mouse_mode

	if _player and is_instance_valid(_player):
		_player.set_control_enabled(true)
		if quill:
			quill.transform = _quill_rest_transform
		if completed:
			_sealed = true
			_finish_scroll_visual()
			WizardHud.toast(self, sealed_prompt)
			scribing_completed.emit(stroke_count)
		else:
			scribing_cancelled.emit()

	_player = null
	_original_camera = null

func _activate_scribe_camera() -> bool:
	_scribe_camera = get_node_or_null(scribe_camera_path) as Camera3D
	if _scribe_camera == null:
		push_error("RuneScribingStation requires a Camera3D at scribe_camera_path.")
		return false
	_move_scribe_camera_to_pose(_scroll_camera_pose, true)
	_scribe_camera.make_current()
	return true


func _move_scribe_camera_to_pose(pose: Node3D, immediate: bool = false) -> void:
	if _scribe_camera == null or pose == null:
		return
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = null
	if immediate or camera_transition_time <= 0.0:
		_scribe_camera.transform = pose.transform
		return
	_camera_tween = create_tween()
	_camera_tween.set_trans(Tween.TRANS_QUART)
	_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(_scribe_camera, "transform", pose.transform, camera_transition_time)


func _configure_rune_recognizer() -> void:
	_rune_recognizer = RuneRecognizerResource.new()
	if not load_rune_templates_on_ready:
		return
	var error := _rune_recognizer.call("load_templates_from_directory", rune_template_directory) as Error
	if error != OK and error != ERR_FILE_NOT_FOUND and error != ERR_DOES_NOT_EXIST:
		push_warning("Could not load rune templates from %s: %s" % [rune_template_directory, error_string(error)])


func _create_scribe_surface() -> void:
	if _scribe_viewport != null and _scribe_canvas != null and _scribe_surface != null:
		return

	_scribe_viewport = SubViewport.new()
	_scribe_viewport.name = "ScribeInkViewport"
	_scribe_viewport.transparent_bg = true
	_scribe_viewport.disable_3d = true
	_scribe_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_scribe_viewport.size = scribe_texture_size
	add_child(_scribe_viewport)

	var scroll_size := _scroll_size()
	var surface_size := _scribe_surface_size()
	_scribe_canvas = ScribeCanvas.new()
	_scribe_canvas.name = "ScribeCanvas"
	_scribe_canvas.initial_strokes = _session.duplicate_strokes(_session.saved_strokes)
	_scribe_canvas.show_measurements = show_scroll_measurements
	_scribe_canvas.canvas_size_mm = surface_size * 1000.0
	_scribe_canvas.major_tick_mm = measurement_major_tick_mm
	_scribe_canvas.minor_tick_mm = measurement_minor_tick_mm
	_scribe_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scribe_canvas.strokes_changed.connect(_on_canvas_strokes_changed)
	_scribe_viewport.add_child(_scribe_canvas)

	_scribe_surface = MeshInstance3D.new()
	_scribe_surface.name = "ScribeInkSurface"
	var mesh := PlaneMesh.new()
	mesh.size = surface_size
	_scribe_surface.mesh = mesh
	_scribe_surface.position = Vector3(0.0, scroll_size.y * 0.5 + ink_lift, 0.0)
	_scribe_surface.rotation_degrees.y = scribe_surface_rotation_degrees
	_scribe_surface.material_override = _scribe_surface_material()
	scroll.add_child(_scribe_surface)


func _on_canvas_strokes_changed(strokes: Array[PackedVector2Array]) -> void:
	_session.save_strokes(strokes)


func _set_cursor_point(point: Vector2) -> void:
	_last_cursor_point = point
	_has_cursor_point = true


func _finish_scroll_visual() -> void:
	if scroll is GeometryInstance3D:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.82, 0.72, 0.52)
		material.emission_enabled = true
		material.emission = Color(0.25, 0.72, 1.0)
		material.emission_energy_multiplier = 0.35
		(scroll as GeometryInstance3D).material_override = material


func _result_rune_name(result: Resource) -> String:
	var rune := result.get("rune") as Resource
	if rune == null:
		return "rune"
	var display_name: Variant = rune.get("display_name")
	if display_name is String and not String(display_name).is_empty():
		return display_name as String
	var id: Variant = rune.get("id")
	if id is StringName:
		return String(id).capitalize()
	if id is String:
		return String(id).capitalize()
	return "rune"


func _update_scribe_props(delta: float) -> void:
	if not _has_cursor_point or quill == null or quill_tip == null \
			or quill_scribe_pose == null:
		return

	var cursor_global := _scribe_surface.to_global(_scribe_surface_point(_last_cursor_point))
	var prop_basis := _scribe_prop_basis()
	var surface_normal := _scribe_surface.global_transform.basis.y.normalized()
	var tip_local := quill.to_local(quill_tip.global_position)
	var desired_origin := cursor_global + surface_normal * quill_hover_lift - prop_basis * tip_local
	var weight := 1.0 if prop_follow_speed <= 0.0 else clampf(prop_follow_speed * delta, 0.0, 1.0)

	var current_origin := quill.global_position
	quill.global_transform = Transform3D(prop_basis, current_origin.lerp(desired_origin, weight))


func _scribe_prop_basis() -> Basis:
	return quill_scribe_pose.global_transform.basis.orthonormalized()


func _scribe_surface_point(point: Vector2) -> Vector3:
	var surface_size := _scribe_surface_size()
	return Vector3(
		(point.x - 0.5) * surface_size.x,
		0.0,
		(point.y - 0.5) * surface_size.y)


func _scroll_point_from_screen(screen_position: Vector2) -> Variant:
	if _scribe_camera == null or _scribe_surface == null:
		return null

	var plane_point := _scribe_surface.global_position
	var plane_normal := _scribe_surface.global_transform.basis.y.normalized()
	var plane := Plane(plane_normal, plane_point)
	var ray_origin := _scribe_camera.project_ray_origin(screen_position)
	var ray_direction := _scribe_camera.project_ray_normal(screen_position)
	var intersection = plane.intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		return null

	var local_point := _scribe_surface.to_local(intersection)
	var surface_size := _scribe_surface_size()
	var point := Vector2(
		local_point.x / surface_size.x + 0.5,
		local_point.z / surface_size.y + 0.5)
	if point.x < 0.0 or point.x > 1.0 or point.y < 0.0 or point.y > 1.0:
		return null
	return point


func _scroll_size() -> Vector3:
	var size = scroll.get("size")
	if size is Vector3:
		return size as Vector3
	return Vector3(0.36, 0.02, 0.29)


func _scribe_surface_size() -> Vector2:
	if scribe_surface_size_m.x > 0.0 and scribe_surface_size_m.y > 0.0:
		return scribe_surface_size_m
	var scroll_size := _scroll_size()
	return Vector2(scroll_size.x, scroll_size.z)


func _scribe_surface_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = _scribe_viewport.get_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
