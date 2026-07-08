extends Node3D

signal scribing_started
signal scribing_completed(stroke_count: int)
signal scribing_cancelled

@export var prompt_text := "Begin scribing"
@export var held_item_prompt := "Empty your hands first"
@export var active_prompt := "Scribing - hold Space to seal"
@export var sealed_prompt := "Spell sealed"

@export_group("Scribing")
## Input action the player holds to seal a spell after drawing at least one mark.
@export var seal_action: StringName = &"jump"
## Seconds the seal action must be held before the spell completes.
@export var seal_hold_time: float = 0.8
## Width of the physical ink mesh drawn back onto the table scroll.
@export var ink_width: float = 0.007
## Small vertical offset that keeps physical ink from z-fighting with the scroll.
@export var ink_lift: float = 0.014
## Scales the physical table ink around the scroll center. Raise this if table ink looks smaller than scribe-mode ink.
@export var table_ink_scale := Vector2(1.18, 1.18)
## Pixel size of the render texture that is projected onto the scroll surface.
@export var scribe_texture_size := Vector2i(1024, 768)

@export_group("Table Camera")
@export_multiline var table_camera_notes := "Scribing requires this Camera3D. Move, rotate, and tune its FOV directly in the crafting table scene for exact composition."
## Required Camera3D in the crafting table scene. Move this camera in the editor for exact scribing composition.
@export_node_path("Camera3D") var scribe_camera_path: NodePath = ^"ScribeCamera"

@export_group("Scribe Props")
## Existing quill node moved during scribing. Leave as Quill for the current crafting table scene.
@export_node_path("Node3D") var quill_path: NodePath = ^"Quill"
## 0 locks directly to the mouse. Higher values add catch-up smoothing.
@export var prop_follow_speed: float = 0.0
## How far above the scroll surface the quill body rides while the tip follows the cursor.
@export var quill_hover_lift: float = 0.002
## Local offset from the quill origin to the writing tip.
@export var quill_tip_local_offset := Vector3(0.0, -0.038, 0.0)
## How much the quill leans forward over the scroll.
@export var quill_pitch_degrees: float = -54.0
## Rotates the quill around the scroll surface normal.
@export var quill_yaw_degrees: float = -36.0
## Position of the simple hand prop relative to the quill origin.
@export var hand_offset := Vector3(0.032, 0.018, 0.016)
## Rotation of the simple hand prop relative to the quill.
@export var hand_rotation_degrees := Vector3(-28.0, -8.0, 26.0)

@onready var scroll: Node3D = $Scroll
@onready var quill: Node3D = get_node_or_null(quill_path) as Node3D

var _active := false
var _sealed := false
var _player: Node3D
var _original_camera: Camera3D
var _scribe_camera: Camera3D
var _scribe_viewport: SubViewport
var _scribe_surface: MeshInstance3D
var _scribe_canvas: ScribeCanvas
var _saved_strokes: Array[PackedVector2Array] = []
var _seal_hold_elapsed := 0.0
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _interactor: RayCast3D
var _scribe_hand: Node3D
var _quill_rest_transform := Transform3D.IDENTITY
var _last_cursor_point := Vector2(0.5, 0.5)
var _has_cursor_point := false


func _ready() -> void:
	if quill:
		_quill_rest_transform = quill.transform
	_create_scribe_surface()
	_create_scribe_hand_prop()


class ScribeCanvas:
	extends Control

	signal strokes_changed(strokes: Array[PackedVector2Array])

	var initial_strokes: Array[PackedVector2Array] = []
	var total_length := 0.0
	var strokes: Array[PackedVector2Array] = []
	var sparkles: Array[Dictionary] = []
	var seal_hold_progress := 0.0
	var _drawing := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)
		_load_initial_strokes()

	func _process(delta: float) -> void:
		for i in range(sparkles.size() - 1, -1, -1):
			sparkles[i]["age"] = float(sparkles[i]["age"]) + delta
			if float(sparkles[i]["age"]) > 0.42:
				sparkles.remove_at(i)
		queue_redraw()

	func _draw() -> void:
		for stroke in strokes:
			if stroke.size() >= 2:
				draw_polyline(_stroke_to_pixels(stroke), Color(0.12, 0.08, 0.16, 0.92), 6.0, true)
			elif stroke.size() == 1:
				draw_circle(_point_to_pixel(stroke[0]), 3.0, Color(0.12, 0.08, 0.16, 0.92))

		for sparkle in sparkles:
			var age := float(sparkle["age"])
			var point := _point_to_pixel(sparkle["point"] as Vector2)
			var alpha := 1.0 - age / 0.42
			var radius := 3.0 + age * 24.0
			draw_circle(point, radius, Color(0.45, 0.9, 1.0, alpha * 0.7))
			draw_circle(point, 2.0, Color(0.95, 1.0, 1.0, alpha))

		if has_ink():
			var bar_back := Rect2(
				Vector2(size.x * 0.08, size.y - 24.0),
				Vector2(size.x * 0.84, 7.0))
			var bar_rect := Rect2(
				bar_back.position,
				Vector2(bar_back.size.x * seal_hold_progress, bar_back.size.y))
			draw_rect(bar_back, Color(0.12, 0.18, 0.22, 0.55), true)
			draw_rect(bar_rect, Color(0.35, 0.82, 1.0, 0.85), true)

	func _begin_stroke(point: Vector2) -> void:
		_drawing = true
		var stroke := PackedVector2Array()
		stroke.append(_clamp_normalized(point))
		strokes.append(stroke)
		_add_sparkle(point)
		strokes_changed.emit(_normalized_strokes())

	func _append_point(point: Vector2) -> void:
		if strokes.is_empty():
			_begin_stroke(point)
			return

		var stroke := strokes[strokes.size() - 1]
		var previous := stroke[stroke.size() - 1]
		var normalized_point := _clamp_normalized(point)
		if _point_to_pixel(previous).distance_to(_point_to_pixel(normalized_point)) < 4.0:
			return

		total_length += _point_to_pixel(previous).distance_to(_point_to_pixel(normalized_point))
		stroke.append(normalized_point)
		strokes[strokes.size() - 1] = stroke

		if int(total_length) % 70 < 8:
			_add_sparkle(normalized_point)
		strokes_changed.emit(_normalized_strokes())

	func _add_sparkle(point: Vector2) -> void:
		sparkles.append({
			"point": _clamp_normalized(point),
			"age": 0.0,
		})

	func has_ink() -> bool:
		return not strokes.is_empty()

	func begin_surface_stroke(point: Vector2) -> void:
		_begin_stroke(point)

	func append_surface_point(point: Vector2) -> void:
		if _drawing:
			_append_point(point)

	func end_surface_stroke() -> void:
		_drawing = false

	func _load_initial_strokes() -> void:
		_load_strokes(initial_strokes)

	func _load_strokes(source_strokes: Array[PackedVector2Array]) -> void:
		strokes.clear()
		for normalized_stroke in source_strokes:
			var stroke := PackedVector2Array()
			for point in normalized_stroke:
				stroke.append(_clamp_normalized(point))
			strokes.append(stroke)
		total_length = _stroke_length(strokes)

	func _normalized_strokes() -> Array[PackedVector2Array]:
		var out: Array[PackedVector2Array] = []
		for stroke in strokes:
			out.append(PackedVector2Array(stroke))
		return out

	func _stroke_length(source_strokes: Array[PackedVector2Array]) -> float:
		var length := 0.0
		for stroke in source_strokes:
			for i in range(1, stroke.size()):
				length += _point_to_pixel(stroke[i - 1]).distance_to(_point_to_pixel(stroke[i]))
		return length

	func _stroke_to_pixels(stroke: PackedVector2Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for point in stroke:
			out.append(_point_to_pixel(point))
		return out

	func _point_to_pixel(point: Vector2) -> Vector2:
		return Vector2(point.x * size.x, point.y * size.y)

	func _clamp_normalized(point: Vector2) -> Vector2:
		return Vector2(clampf(point.x, 0.0, 1.0), clampf(point.y, 0.0, 1.0))


func interact(player: Node3D, _collider: Object) -> void:
	if _active:
		return
	if _sealed:
		_show_toast(player, sealed_prompt)
		return

	var hands := _hands_for(player)
	if hands == null:
		return
	if hands.held_item != null:
		_show_toast(player, held_item_prompt)
		return

	_begin_scribing(player)


func focus_prompt(player: Node3D, _collider: Object) -> String:
	if _active:
		return ""
	if _sealed:
		return sealed_prompt

	var hands := _hands_for(player)
	if hands == null:
		return ""
	if hands.held_item != null:
		return held_item_prompt
	return prompt_text


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		_end_scribing(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_LEFT:
			var point: Variant = _scroll_point_from_screen(button_event.position)
			if button_event.pressed and point != null:
				_scribe_canvas.begin_surface_stroke(point as Vector2)
				_set_cursor_point(point as Vector2)
				get_viewport().set_input_as_handled()
			elif not button_event.pressed:
				_scribe_canvas.end_surface_stroke()
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

	if _scribe_canvas.has_ink() and Input.is_action_pressed(seal_action):
		_seal_hold_elapsed = minf(_seal_hold_elapsed + delta, seal_hold_time)
		_scribe_canvas.seal_hold_progress = _seal_hold_elapsed / maxf(seal_hold_time, 0.001)
		if _seal_hold_elapsed >= seal_hold_time:
			_end_scribing(true, _scribe_canvas.strokes.size())
	else:
		_seal_hold_elapsed = 0.0
		_scribe_canvas.seal_hold_progress = 0.0


func _begin_scribing(player: Node3D) -> void:
	_active = true
	_player = player
	_seal_hold_elapsed = 0.0
	_previous_mouse_mode = Input.mouse_mode
	_original_camera = get_viewport().get_camera_3d()
	_interactor = player.get_node_or_null("%Interactor") as RayCast3D
	_clear_interaction_prompt()
	_last_cursor_point = Vector2(0.5, 0.5)
	_has_cursor_point = true
	if _scribe_hand:
		_scribe_hand.visible = true

	if not _create_scribe_camera():
		_active = false
		return
	_lock_player(player, true)
	_create_scribe_surface()
	_update_scribe_props(1.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	scribing_started.emit()


func _end_scribing(completed: bool, stroke_count: int = 0) -> void:
	if not _active:
		return

	_active = false
	if _original_camera and is_instance_valid(_original_camera):
		_original_camera.make_current()

	_scribe_camera = null
	Input.mouse_mode = _previous_mouse_mode

	if _player and is_instance_valid(_player):
		_lock_player(_player, false)
		if _scribe_hand:
			_scribe_hand.visible = false
		if quill:
			quill.transform = _quill_rest_transform
		if completed:
			_sealed = true
			_finish_scroll_visual()
			_show_toast(_player, "Scroll scribed")
			scribing_completed.emit(stroke_count)
		else:
			scribing_cancelled.emit()

	_player = null
	_original_camera = null
	_interactor = null


func _create_scribe_camera() -> bool:
	_scribe_camera = get_node_or_null(scribe_camera_path) as Camera3D
	if _scribe_camera == null:
		push_error("SpellCrafter requires a Camera3D at scribe_camera_path.")
		return false
	_scribe_camera.make_current()
	return true


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

	_scribe_canvas = ScribeCanvas.new()
	_scribe_canvas.name = "ScribeCanvas"
	_scribe_canvas.initial_strokes = _duplicate_strokes(_saved_strokes)
	_scribe_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scribe_canvas.strokes_changed.connect(_on_canvas_strokes_changed)
	_scribe_viewport.add_child(_scribe_canvas)

	_scribe_surface = MeshInstance3D.new()
	_scribe_surface.name = "ScribeInkSurface"
	var mesh := PlaneMesh.new()
	var scroll_size := _scroll_size()
	mesh.size = Vector2(scroll_size.x * table_ink_scale.x, scroll_size.z * table_ink_scale.y)
	_scribe_surface.mesh = mesh
	_scribe_surface.position = Vector3(0.0, scroll_size.y * 0.5 + ink_lift, 0.0)
	_scribe_surface.material_override = _scribe_surface_material()
	scroll.add_child(_scribe_surface)


func _on_canvas_strokes_changed(strokes: Array[PackedVector2Array]) -> void:
	_saved_strokes = _duplicate_strokes(strokes)


func _set_cursor_point(point: Vector2) -> void:
	_last_cursor_point = point
	_has_cursor_point = true


func _lock_player(player: Node3D, locked: bool) -> void:
	player.set_physics_process(not locked)
	player.set_process_input(not locked)
	player.set_process_unhandled_input(not locked)
	if _interactor:
		_interactor.enabled = not locked
		_interactor.set_physics_process(not locked)
		_interactor.set_process_unhandled_input(not locked)


func _finish_scroll_visual() -> void:
	if scroll is GeometryInstance3D:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.82, 0.72, 0.52)
		material.emission_enabled = true
		material.emission = Color(0.25, 0.72, 1.0)
		material.emission_energy_multiplier = 0.35
		(scroll as GeometryInstance3D).material_override = material


func _create_scribe_hand_prop() -> void:
	if _scribe_hand:
		return

	_scribe_hand = Node3D.new()
	_scribe_hand.name = "ScribeHand"
	_scribe_hand.visible = false
	add_child(_scribe_hand)

	var skin_material := StandardMaterial3D.new()
	skin_material.albedo_color = Color(0.78, 0.52, 0.36)
	skin_material.roughness = 0.72

	var palm_mesh := SphereMesh.new()
	palm_mesh.radius = 0.034
	palm_mesh.height = 0.045
	var palm := MeshInstance3D.new()
	palm.name = "Palm"
	palm.mesh = palm_mesh
	palm.material_override = skin_material
	palm.position = Vector3(0.0, 0.0, 0.0)
	palm.scale = Vector3(1.1, 0.7, 0.85)
	_scribe_hand.add_child(palm)

	for i in 4:
		var finger_mesh := CapsuleMesh.new()
		finger_mesh.radius = 0.006
		finger_mesh.height = 0.052
		var finger := MeshInstance3D.new()
		finger.name = "Finger%d" % (i + 1)
		finger.mesh = finger_mesh
		finger.material_override = skin_material
		finger.position = Vector3(-0.021 + i * 0.014, -0.018, -0.018)
		finger.rotation_degrees = Vector3(72.0, 0.0, -10.0 + i * 5.0)
		_scribe_hand.add_child(finger)

	var thumb_mesh := CapsuleMesh.new()
	thumb_mesh.radius = 0.007
	thumb_mesh.height = 0.048
	var thumb := MeshInstance3D.new()
	thumb.name = "Thumb"
	thumb.mesh = thumb_mesh
	thumb.material_override = skin_material
	thumb.position = Vector3(0.031, -0.012, 0.006)
	thumb.rotation_degrees = Vector3(55.0, 28.0, -42.0)
	_scribe_hand.add_child(thumb)

	if quill and quill.get_node_or_null("WritingTip") == null:
		var tip_material := StandardMaterial3D.new()
		tip_material.albedo_color = Color(0.04, 0.025, 0.035)
		tip_material.roughness = 0.38

		var tip_mesh := CylinderMesh.new()
		tip_mesh.bottom_radius = 0.009
		tip_mesh.top_radius = 0.0
		tip_mesh.height = 0.03
		var tip := MeshInstance3D.new()
		tip.name = "WritingTip"
		tip.mesh = tip_mesh
		tip.material_override = tip_material
		tip.position = quill_tip_local_offset
		tip.rotation_degrees = Vector3(180.0, 0.0, 0.0)
		quill.add_child(tip)


func _update_scribe_props(delta: float) -> void:
	if not _has_cursor_point:
		return

	var scroll_size := _scroll_size()
	var top_y := scroll_size.y * 0.5 + ink_lift
	var cursor_local := _scroll_point(_last_cursor_point, scroll_size, top_y)
	var cursor_global := scroll.to_global(cursor_local)
	var prop_basis := _scribe_prop_basis()
	var surface_normal := scroll.global_transform.basis.y.normalized()
	var desired_origin := cursor_global + surface_normal * quill_hover_lift - prop_basis * quill_tip_local_offset
	var weight := 1.0 if prop_follow_speed <= 0.0 else clampf(prop_follow_speed * delta, 0.0, 1.0)

	if quill:
		var current_origin := quill.global_position
		quill.global_transform = Transform3D(prop_basis, current_origin.lerp(desired_origin, weight))

	if _scribe_hand:
		_scribe_hand.visible = true
		var hand_basis := prop_basis * Basis.from_euler(Vector3(
			deg_to_rad(hand_rotation_degrees.x),
			deg_to_rad(hand_rotation_degrees.y),
			deg_to_rad(hand_rotation_degrees.z)))
		var hand_origin := desired_origin + prop_basis * hand_offset
		_scribe_hand.global_transform = Transform3D(hand_basis, _scribe_hand.global_position.lerp(hand_origin, weight))


func _scribe_prop_basis() -> Basis:
	var basis := scroll.global_transform.basis.orthonormalized()
	basis = basis.rotated(scroll.global_transform.basis.y.normalized(), deg_to_rad(quill_yaw_degrees))
	basis = basis.rotated(basis.x.normalized(), deg_to_rad(quill_pitch_degrees))
	return basis.orthonormalized()


func _clear_interaction_prompt() -> void:
	if _interactor and _interactor.has_signal("focus_changed"):
		_interactor.emit_signal("focus_changed", "")


func _scroll_point(point: Vector2, scroll_size: Vector3, top_y: float) -> Vector3:
	return Vector3(
		(point.x - 0.5) * scroll_size.x * table_ink_scale.x,
		top_y,
		(point.y - 0.5) * scroll_size.z * table_ink_scale.y)


func _scroll_point_from_screen(screen_position: Vector2) -> Variant:
	if _scribe_camera == null:
		return null

	var scroll_size := _scroll_size()
	var top_y := scroll_size.y * 0.5 + ink_lift
	var plane_point := scroll.to_global(Vector3(0.0, top_y, 0.0))
	var plane_normal := scroll.global_transform.basis.y.normalized()
	var plane := Plane(plane_normal, plane_point)
	var ray_origin := _scribe_camera.project_ray_origin(screen_position)
	var ray_direction := _scribe_camera.project_ray_normal(screen_position)
	var intersection = plane.intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		return null

	var local_point := scroll.to_local(intersection)
	var width := scroll_size.x * table_ink_scale.x
	var height := scroll_size.z * table_ink_scale.y
	var point := Vector2(local_point.x / width + 0.5, local_point.z / height + 0.5)
	if point.x < 0.0 or point.x > 1.0 or point.y < 0.0 or point.y > 1.0:
		return null
	return point


func _scroll_size() -> Vector3:
	var size = scroll.get("size")
	if size is Vector3:
		return size as Vector3
	return Vector3(0.36, 0.02, 0.29)


func _scribe_surface_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = _scribe_viewport.get_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _duplicate_strokes(source: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for stroke in source:
		out.append(PackedVector2Array(stroke))
	return out


func _show_toast(player: Node3D, message: String) -> void:
	var hud := player.get_tree().get_first_node_in_group("wizard_hud")
	if hud and hud.has_method("show_toast"):
		hud.call("show_toast", message)


func _scene_parent() -> Node:
	return get_tree().current_scene if get_tree().current_scene != null else get_tree().root


func _hands_for(player: Node3D) -> Node:
	if player == null:
		return null
	var hands := player.get_node_or_null("%HandAnchor")
	if hands == null or not hands.has_method("pick_up"):
		return null
	return hands
