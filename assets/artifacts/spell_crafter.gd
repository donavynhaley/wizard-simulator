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

@export_group("Table Camera")
@export_multiline var table_camera_notes := "Height raises or lowers the scribe camera. Back moves it away from the scroll along the table's local Z axis. Pitch tilts toward or away from the scroll, yaw rotates left or right, and roll rotates the final view. Roll -90 points the parchment to the right."
## Vertical distance above the scroll center.
@export var camera_height: float = 1.15
## Distance behind the scroll center along this table's local Z axis.
@export var camera_back: float = 0.25
## Field of view for the temporary scribing camera.
@export var camera_fov: float = 48.0
## Extra local pitch after the camera looks at the scroll.
@export var camera_pitch_offset_degrees: float = 0.0
## Extra local yaw after the camera looks at the scroll.
@export var camera_yaw_offset_degrees: float = 0.0
## Extra local roll after the camera looks at the scroll. Use this to rotate the parchment in screen space.
@export var camera_roll_degrees: float = -90.0

@export_group("Scribe Props")
## Existing quill node moved during scribing. Leave as Quill for the current crafting table scene.
@export_node_path("Node3D") var quill_path: NodePath = ^"Quill"
## Higher values make the quill and hand catch up to the mouse faster.
@export var prop_follow_speed: float = 28.0
## How far above the scroll surface the quill body rides while the tip follows the cursor.
@export var quill_hover_lift: float = 0.006
## Local offset from the quill origin to the writing tip.
@export var quill_tip_local_offset := Vector3(0.0, -0.04, 0.0)
## How much the quill leans forward over the scroll.
@export var quill_pitch_degrees: float = -62.0
## Rotates the quill around the scroll surface normal.
@export var quill_yaw_degrees: float = -28.0
## Position of the simple hand prop relative to the quill origin.
@export var hand_offset := Vector3(0.025, 0.025, 0.01)
## Rotation of the simple hand prop relative to the quill.
@export var hand_rotation_degrees := Vector3(-18.0, -12.0, 22.0)

@onready var scroll: Node3D = $Scroll
@onready var quill: Node3D = get_node_or_null(quill_path) as Node3D

var _active := false
var _sealed := false
var _player: Node3D
var _original_camera: Camera3D
var _scribe_camera: Camera3D
var _scribe_layer: CanvasLayer
var _scribe_canvas: ScribeCanvas
var _saved_strokes: Array[PackedVector2Array] = []
var _scroll_ink: MeshInstance3D
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
	_create_scribe_hand_prop()


class ScribeCanvas:
	extends Control

	signal strokes_changed(strokes: Array[PackedVector2Array])
	signal cursor_changed(point: Vector2, inside: bool)

	var initial_strokes: Array[PackedVector2Array] = []
	var total_length := 0.0
	var strokes: Array[PackedVector2Array] = []
	var sparkles: Array[Dictionary] = []
	var seal_hold_progress := 0.0
	var _drawing := false
	var _scroll_rect := Rect2()
	var _last_cursor := Vector2.INF
	var _last_cursor_inside := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_process(true)
		_update_scroll_rect()
		_load_initial_strokes()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			var normalized := _normalized_strokes()
			_update_scroll_rect()
			_load_strokes(normalized)
			queue_redraw()

	func _process(delta: float) -> void:
		for i in range(sparkles.size() - 1, -1, -1):
			sparkles[i]["age"] = float(sparkles[i]["age"]) + delta
			if float(sparkles[i]["age"]) > 0.42:
				sparkles.remove_at(i)
		_emit_cursor_from_mouse()
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var button_event := event as InputEventMouseButton
			if button_event.button_index != MOUSE_BUTTON_LEFT:
				return
			if button_event.pressed and _scroll_rect.has_point(button_event.position):
				_begin_stroke(button_event.position)
				_emit_cursor(button_event.position, true)
			elif not button_event.pressed:
				_drawing = false
			accept_event()
			return

		if event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			var clamped := motion.position.clamp(_scroll_rect.position, _scroll_rect.end)
			_emit_cursor(clamped, _scroll_rect.has_point(motion.position))
			if _drawing:
				_append_point(clamped)
			accept_event()

	func _draw() -> void:
		draw_rect(_scroll_rect, Color(0.86, 0.78, 0.62, 0.08), true)
		draw_rect(_scroll_rect, Color(0.98, 0.91, 0.72, 0.65), false, 2.0)

		for stroke in strokes:
			if stroke.size() >= 2:
				draw_polyline(stroke, Color(0.12, 0.08, 0.16, 0.92), 4.0, true)

		for sparkle in sparkles:
			var age := float(sparkle["age"])
			var point := sparkle["point"] as Vector2
			var alpha := 1.0 - age / 0.42
			var radius := 3.0 + age * 24.0
			draw_circle(point, radius, Color(0.45, 0.9, 1.0, alpha * 0.7))
			draw_circle(point, 2.0, Color(0.95, 1.0, 1.0, alpha))

		if has_ink():
			var bar_back := Rect2(
				_scroll_rect.position + Vector2(0.0, _scroll_rect.size.y + 18.0),
				Vector2(_scroll_rect.size.x, 5.0))
			var bar_rect := Rect2(
				_scroll_rect.position + Vector2(0.0, _scroll_rect.size.y + 18.0),
				Vector2(_scroll_rect.size.x * seal_hold_progress, 5.0))
			draw_rect(bar_back, Color(0.12, 0.18, 0.22, 0.55), true)
			draw_rect(bar_rect, Color(0.35, 0.82, 1.0, 0.85), true)

	func _begin_stroke(point: Vector2) -> void:
		_drawing = true
		var stroke := PackedVector2Array()
		stroke.append(point)
		strokes.append(stroke)
		_add_sparkle(point)
		strokes_changed.emit(_normalized_strokes())

	func _append_point(point: Vector2) -> void:
		if strokes.is_empty():
			_begin_stroke(point)
			return

		var stroke := strokes[strokes.size() - 1]
		var previous := stroke[stroke.size() - 1]
		if previous.distance_to(point) < 4.0:
			return

		total_length += previous.distance_to(point)
		stroke.append(point)
		strokes[strokes.size() - 1] = stroke

		if int(total_length) % 70 < 8:
			_add_sparkle(point)
		strokes_changed.emit(_normalized_strokes())

	func _add_sparkle(point: Vector2) -> void:
		sparkles.append({
			"point": point,
			"age": 0.0,
		})

	func _update_scroll_rect() -> void:
		var size := get_viewport_rect().size
		var width := minf(size.x * 0.48, 620.0)
		var height := width * 0.72
		_scroll_rect = Rect2((size - Vector2(width, height)) * 0.5, Vector2(width, height))

	func _emit_cursor_from_mouse() -> void:
		var mouse_position := get_local_mouse_position()
		var clamped := mouse_position.clamp(_scroll_rect.position, _scroll_rect.end)
		_emit_cursor(clamped, _scroll_rect.has_point(mouse_position))

	func _emit_cursor(point: Vector2, inside: bool) -> void:
		if point.distance_squared_to(_last_cursor) < 1.0 and inside == _last_cursor_inside:
			return
		_last_cursor = point
		_last_cursor_inside = inside
		cursor_changed.emit(_normalized_point(point), inside)

	func has_ink() -> bool:
		return not strokes.is_empty()

	func _load_initial_strokes() -> void:
		_load_strokes(initial_strokes)

	func _load_strokes(source_strokes: Array[PackedVector2Array]) -> void:
		strokes.clear()
		for normalized_stroke in source_strokes:
			var stroke := PackedVector2Array()
			for point in normalized_stroke:
				stroke.append(_scroll_rect.position + point * _scroll_rect.size)
			strokes.append(stroke)
		total_length = _stroke_length(strokes)

	func _normalized_strokes() -> Array[PackedVector2Array]:
		var out: Array[PackedVector2Array] = []
		if _scroll_rect.size.x <= 0.0 or _scroll_rect.size.y <= 0.0:
			return out
		for stroke in strokes:
			var normalized := PackedVector2Array()
			for point in stroke:
				normalized.append(_normalized_point(point))
			out.append(normalized)
		return out

	func _normalized_point(point: Vector2) -> Vector2:
		if _scroll_rect.size.x <= 0.0 or _scroll_rect.size.y <= 0.0:
			return Vector2(0.5, 0.5)
		return Vector2(
			(point.x - _scroll_rect.position.x) / _scroll_rect.size.x,
			(point.y - _scroll_rect.position.y) / _scroll_rect.size.y)

	func _stroke_length(source_strokes: Array[PackedVector2Array]) -> float:
		var length := 0.0
		for stroke in source_strokes:
			for i in range(1, stroke.size()):
				length += stroke[i - 1].distance_to(stroke[i])
		return length


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
		return active_prompt
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


func _process(delta: float) -> void:
	if not _active or _scribe_canvas == null:
		return

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
	_last_cursor_point = Vector2(0.5, 0.5)
	_has_cursor_point = true
	if _scroll_ink:
		_scroll_ink.visible = false
	if _scribe_hand:
		_scribe_hand.visible = true

	_lock_player(player, true)
	_create_scribe_camera()
	_create_scribe_overlay()
	_update_scribe_props(1.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	scribing_started.emit()


func _end_scribing(completed: bool, stroke_count: int = 0) -> void:
	if not _active:
		return

	_active = false
	if _original_camera and is_instance_valid(_original_camera):
		_original_camera.make_current()
	if _scribe_camera and is_instance_valid(_scribe_camera):
		_scribe_camera.queue_free()
	if _scribe_layer and is_instance_valid(_scribe_layer):
		_scribe_layer.queue_free()

	_scribe_camera = null
	_scribe_layer = null
	_scribe_canvas = null
	Input.mouse_mode = _previous_mouse_mode

	if _player and is_instance_valid(_player):
		_lock_player(_player, false)
		_refresh_scroll_ink()
		if _scroll_ink:
			_scroll_ink.visible = true
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


func _create_scribe_camera() -> void:
	_scribe_camera = Camera3D.new()
	_scribe_camera.name = "SpellCrafterCamera"
	_scribe_camera.fov = camera_fov
	_scene_parent().add_child(_scribe_camera)

	var target := scroll.global_position
	var back := global_transform.basis.z.normalized() * camera_back
	_scribe_camera.global_position = target + Vector3.UP * camera_height + back
	_scribe_camera.look_at(target, _scribe_camera_up(target))
	_scribe_camera.rotate_object_local(Vector3.RIGHT, deg_to_rad(camera_pitch_offset_degrees))
	_scribe_camera.rotate_object_local(Vector3.UP, deg_to_rad(camera_yaw_offset_degrees))
	_scribe_camera.rotate_object_local(Vector3.FORWARD, deg_to_rad(camera_roll_degrees))
	_scribe_camera.make_current()


func _create_scribe_overlay() -> void:
	_scribe_layer = CanvasLayer.new()
	_scribe_layer.name = "ScribeMinigame"
	_scene_parent().add_child(_scribe_layer)

	_scribe_canvas = ScribeCanvas.new()
	_scribe_canvas.name = "ScribeCanvas"
	_scribe_canvas.initial_strokes = _duplicate_strokes(_saved_strokes)
	_scribe_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scribe_canvas.strokes_changed.connect(_on_canvas_strokes_changed)
	_scribe_canvas.cursor_changed.connect(_on_canvas_cursor_changed)
	_scribe_layer.add_child(_scribe_canvas)


func _on_canvas_strokes_changed(strokes: Array[PackedVector2Array]) -> void:
	_saved_strokes = _duplicate_strokes(strokes)


func _on_canvas_cursor_changed(point: Vector2, inside: bool) -> void:
	if not inside:
		return
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
	var weight := clampf(prop_follow_speed * delta, 0.0, 1.0)

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


func _scribe_camera_up(target: Vector3) -> Vector3:
	var view_direction := (target - _scribe_camera.global_position).normalized()
	var up := Vector3.UP
	if absf(view_direction.dot(up)) > 0.96:
		up = global_transform.basis.z.normalized()
		if up.length_squared() <= 0.0001:
			up = Vector3.FORWARD
	return up


func _refresh_scroll_ink() -> void:
	if _scroll_ink == null:
		_scroll_ink = MeshInstance3D.new()
		_scroll_ink.name = "ScribedInk"
		scroll.add_child(_scroll_ink)

	if _saved_strokes.is_empty():
		_scroll_ink.mesh = null
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var scroll_size := _scroll_size()
	var top_y := scroll_size.y * 0.5 + ink_lift

	for stroke in _saved_strokes:
		if stroke.size() == 1:
			_add_ink_dot(vertices, normals, indices, _scroll_point(stroke[0], scroll_size, top_y))
			continue
		for i in range(1, stroke.size()):
			_add_ink_segment(
				vertices,
				normals,
				indices,
				_scroll_point(stroke[i - 1], scroll_size, top_y),
				_scroll_point(stroke[i], scroll_size, top_y))

	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _ink_material())
	_scroll_ink.mesh = mesh


func _add_ink_segment(
		vertices: PackedVector3Array,
		normals: PackedVector3Array,
		indices: PackedInt32Array,
		a: Vector3,
		b: Vector3) -> void:
	var direction := Vector2(b.x - a.x, b.z - a.z)
	if direction.length_squared() <= 0.000001:
		_add_ink_dot(vertices, normals, indices, a)
		return

	var perpendicular := Vector2(-direction.y, direction.x).normalized() * ink_width * 0.5
	var start := vertices.size()
	vertices.append(Vector3(a.x + perpendicular.x, a.y, a.z + perpendicular.y))
	vertices.append(Vector3(a.x - perpendicular.x, a.y, a.z - perpendicular.y))
	vertices.append(Vector3(b.x - perpendicular.x, b.y, b.z - perpendicular.y))
	vertices.append(Vector3(b.x + perpendicular.x, b.y, b.z + perpendicular.y))
	for i in 4:
		normals.append(Vector3.UP)
	indices.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))


func _add_ink_dot(
		vertices: PackedVector3Array,
		normals: PackedVector3Array,
		indices: PackedInt32Array,
		center: Vector3) -> void:
	var half_width := ink_width * 0.65
	var start := vertices.size()
	vertices.append(center + Vector3(-half_width, 0.0, -half_width))
	vertices.append(center + Vector3(half_width, 0.0, -half_width))
	vertices.append(center + Vector3(half_width, 0.0, half_width))
	vertices.append(center + Vector3(-half_width, 0.0, half_width))
	for i in 4:
		normals.append(Vector3.UP)
	indices.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))


func _scroll_point(point: Vector2, scroll_size: Vector3, top_y: float) -> Vector3:
	return Vector3(
		(point.x - 0.5) * scroll_size.x * table_ink_scale.x,
		top_y,
		(point.y - 0.5) * scroll_size.z * table_ink_scale.y)


func _scroll_size() -> Vector3:
	var size = scroll.get("size")
	if size is Vector3:
		return size as Vector3
	return Vector3(0.36, 0.02, 0.29)


func _ink_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.045, 0.12)
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
