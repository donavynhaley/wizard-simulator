class_name BookVisual
extends Node3D

signal page_turn_midpoint_reached
signal page_turn_finished

@export_group("Visual Profile")
@export var default_profile: BookVisualProfile

@export_group("Visual Nodes")
@export_node_path("Node3D") var visual_root_path: NodePath = ^"VisualRoot"
@export_node_path("Node3D") var motion_root_path: NodePath = ^"VisualRoot/MotionRoot"
@export_node_path("Node3D") var closed_visual_path: NodePath = \
	^"VisualRoot/MotionRoot/ClosedVisual"
@export_node_path("Node3D") var open_visual_path: NodePath = \
	^"VisualRoot/MotionRoot/OpenVisual"
@export_node_path("Node3D") var closed_model_socket_path: NodePath = \
	^"VisualRoot/MotionRoot/ClosedVisual/ModelSocket"
@export_node_path("Node3D") var open_model_socket_path: NodePath = \
	^"VisualRoot/MotionRoot/OpenVisual/ModelSocket"
@export_node_path("Node3D") var page_surface_path: NodePath = \
	^"VisualRoot/MotionRoot/OpenVisual/PageSurface"
@export_node_path("MeshInstance3D") var left_page_path: NodePath = \
	^"VisualRoot/MotionRoot/OpenVisual/PageSurface/LeftPage"
@export_node_path("MeshInstance3D") var right_page_path: NodePath = \
	^"VisualRoot/MotionRoot/OpenVisual/PageSurface/RightPage"
@export_node_path("MeshInstance3D") var left_page_stack_path: NodePath = \
	^"VisualRoot/MotionRoot/OpenVisual/PageSurface/LeftPageStack"
@export_node_path("MeshInstance3D") var right_page_stack_path: NodePath = \
	^"VisualRoot/MotionRoot/OpenVisual/PageSurface/RightPageStack"
@export_node_path("MeshInstance3D") var turning_page_path: NodePath = \
	^"VisualRoot/MotionRoot/OpenVisual/PageSurface/TurningPage"
@export_node_path("Marker3D") var left_hand_grip_path: NodePath = \
	^"VisualRoot/MotionRoot/LeftHandGrip"
@export_node_path("Marker3D") var right_hand_grip_path: NodePath = \
	^"VisualRoot/MotionRoot/RightHandGrip"

@export_group("Editor Authored Pose Markers")
@export_node_path("Marker3D") var world_pose_path: NodePath = ^"WorldPose"
@export_node_path("Marker3D") var held_pose_path: NodePath = ^"HeldPose"
@export_node_path("Marker3D") var reading_pose_path: NodePath = ^"ReadingPose"
@export_node_path("Marker3D") var close_focus_pose_path: NodePath = ^"CloseFocusPose"
@export_node_path("Marker3D") var table_pose_path: NodePath = ^"TablePose"
@export_range(0.05, 1.0, 0.01) var pose_transition_seconds: float = 0.32

@export_group("Optional Audio Players")
@export_node_path("AudioStreamPlayer3D") var open_audio_path: NodePath = ^"OpenAudio"
@export_node_path("AudioStreamPlayer3D") var close_audio_path: NodePath = ^"CloseAudio"
@export_node_path("AudioStreamPlayer3D") var page_audio_path: NodePath = ^"PageAudio"

var _visual_root: Node3D
var _motion_root: Node3D
var _closed_visual: Node3D
var _open_visual: Node3D
var _closed_model_socket: Node3D
var _open_model_socket: Node3D
var _page_surface: Node3D
var _left_page: MeshInstance3D
var _right_page: MeshInstance3D
var _left_page_stack: MeshInstance3D
var _right_page_stack: MeshInstance3D
var _turning_page: MeshInstance3D
var _left_hand_grip: Marker3D
var _right_hand_grip: Marker3D
var _world_pose: Marker3D
var _held_pose: Marker3D
var _reading_pose: Marker3D
var _close_focus_pose: Marker3D
var _table_pose: Marker3D
var _open_audio: AudioStreamPlayer3D
var _close_audio: AudioStreamPlayer3D
var _page_audio: AudioStreamPlayer3D
var _pose_tween: Tween
var _turn_tween: Tween
var _opening_held: bool = false
var _reading_active: bool = false
var _close_focused: bool = false
var _turn_direction: int = 1
var _turn_midpoint_emitted: bool = false
var _profile: BookVisualProfile
var _page_texture: Texture2D
var _page_material: StandardMaterial3D
var _page_stack_material: StandardMaterial3D
var _page_progress_ratio: float = 0.5


func _ready() -> void:
	_visual_root = get_node_or_null(visual_root_path) as Node3D
	_motion_root = get_node_or_null(motion_root_path) as Node3D
	_closed_visual = get_node_or_null(closed_visual_path) as Node3D
	_open_visual = get_node_or_null(open_visual_path) as Node3D
	_closed_model_socket = get_node_or_null(closed_model_socket_path) as Node3D
	_open_model_socket = get_node_or_null(open_model_socket_path) as Node3D
	_page_surface = get_node_or_null(page_surface_path) as Node3D
	_left_page = get_node_or_null(left_page_path) as MeshInstance3D
	_right_page = get_node_or_null(right_page_path) as MeshInstance3D
	_left_page_stack = get_node_or_null(left_page_stack_path) as MeshInstance3D
	_right_page_stack = get_node_or_null(right_page_stack_path) as MeshInstance3D
	_turning_page = get_node_or_null(turning_page_path) as MeshInstance3D
	_left_hand_grip = get_node_or_null(left_hand_grip_path) as Marker3D
	_right_hand_grip = get_node_or_null(right_hand_grip_path) as Marker3D
	_world_pose = get_node_or_null(world_pose_path) as Marker3D
	_held_pose = get_node_or_null(held_pose_path) as Marker3D
	_reading_pose = get_node_or_null(reading_pose_path) as Marker3D
	_close_focus_pose = get_node_or_null(close_focus_pose_path) as Marker3D
	_table_pose = get_node_or_null(table_pose_path) as Marker3D
	_open_audio = get_node_or_null(open_audio_path) as AudioStreamPlayer3D
	_close_audio = get_node_or_null(close_audio_path) as AudioStreamPlayer3D
	_page_audio = get_node_or_null(page_audio_path) as AudioStreamPlayer3D
	_create_materials()
	apply_profile(_profile)
	show_world_closed()


func _process(_delta: float) -> void:
	if _motion_root == null or _profile == null:
		return
	var time := Time.get_ticks_msec() * 0.001 * _profile.breathing_speed
	var focus_scale := 0.35 if _close_focused else 1.0
	_motion_root.position.y = sin(time * TAU) * _profile.breathing_lift * focus_scale
	_motion_root.rotation.z = deg_to_rad(sin(time * PI) * _profile.sway_degrees * focus_scale)


func apply_profile(profile: BookVisualProfile) -> void:
	_profile = profile if profile != null else default_profile
	if not is_node_ready() or _profile == null:
		return
	_replace_model(
		_closed_model_socket,
		_profile.closed_model_scene,
		_profile.closed_model_transform,
		"ClosedModel")
	_replace_model(
		_open_model_socket,
		_profile.open_model_scene,
		_profile.open_model_transform,
		"OpenModel")
	_world_pose.transform = _profile.world_pose
	_held_pose.transform = _profile.held_pose
	_reading_pose.transform = _profile.reading_pose
	_close_focus_pose.transform = _profile.close_focus_pose
	_table_pose.transform = _profile.table_pose
	_page_surface.transform = _profile.page_geometry_transform
	_restore_hand_grips()
	_configure_audio()
	_rebuild_page_geometry()


func get_visual_profile() -> BookVisualProfile:
	return _profile


func set_page_texture(texture: Texture2D) -> void:
	_page_texture = texture
	if _page_material != null:
		_page_material.albedo_texture = texture
	_rebuild_page_geometry()


func set_page_progress(spread_index: int, spread_count: int) -> void:
	_page_progress_ratio = 0.5 if spread_count <= 1 else clampf(
		float(spread_index) / float(spread_count - 1),
		0.0,
		1.0)
	if is_node_ready() and _profile != null:
		_configure_page_stack(_left_page_stack, -1)
		_configure_page_stack(_right_page_stack, 1)


func show_world_closed() -> void:
	_opening_held = false
	_set_reading_motion_active(false)
	_close_focused = false
	cancel_page_turn()
	_kill_pose_tween()
	_apply_pose(_world_pose)
	_set_open(false)


func show_held_closed() -> void:
	_opening_held = false
	_set_reading_motion_active(false)
	_close_focused = false
	cancel_page_turn()
	_kill_pose_tween()
	_apply_pose(_held_pose)
	_set_open(false)


func open_held() -> void:
	_opening_held = true
	_set_reading_motion_active(true)
	_close_focused = false
	_set_open(true)
	_play_audio(_open_audio, _profile.open_sound if _profile != null else null)
	_tween_to_pose(_reading_pose, false, true)


func close_held() -> void:
	_opening_held = false
	_set_reading_motion_active(false)
	_close_focused = false
	cancel_page_turn()
	_play_audio(_close_audio, _profile.close_sound if _profile != null else null)
	_tween_to_pose(_held_pose, true)


func set_close_focus(enabled: bool) -> void:
	if not _reading_active or enabled == _close_focused:
		return
	_close_focused = enabled
	_tween_to_pose(_close_focus_pose if enabled else _reading_pose)


func is_close_focused() -> bool:
	return _close_focused


func get_hand_grip_transforms() -> Array[Transform3D]:
	var grips: Array[Transform3D] = []
	if _left_hand_grip != null and _right_hand_grip != null:
		grips.assign([
			_left_hand_grip.global_transform,
			_right_hand_grip.global_transform,
		])
	return grips


func show_table_open() -> void:
	_opening_held = false
	_set_reading_motion_active(false)
	_close_focused = false
	cancel_page_turn()
	_kill_pose_tween()
	_apply_pose(_table_pose)
	_set_open(true)


func play_page_turn(direction: int) -> bool:
	if _profile == null or _turning_page == null or _turn_tween != null:
		return false
	_turn_direction = 1 if direction >= 0 else -1
	_turn_midpoint_emitted = false
	_turning_page.visible = true
	if _turn_direction > 0:
		_right_page.visible = false
	else:
		_left_page.visible = false
	_set_page_turn_progress(0.0)
	_play_audio(_page_audio, _profile.page_turn_sound)
	_turn_tween = create_tween()
	_turn_tween.tween_method(
		_set_page_turn_progress,
		0.0,
		1.0,
		_profile.page_turn_seconds
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_turn_tween.tween_callback(_finish_page_turn)
	return true


func cancel_page_turn() -> void:
	if _turn_tween != null and _turn_tween.is_valid():
		_turn_tween.kill()
	_turn_tween = null
	_turn_midpoint_emitted = false
	if _turning_page != null:
		_turning_page.visible = false
	if _left_page != null:
		_left_page.visible = true
	if _right_page != null:
		_right_page.visible = true
	_restore_hand_grips()


func _set_page_turn_progress(progress: float) -> void:
	if _turning_page == null or _profile == null:
		return
	_turning_page.mesh = _build_turning_page_mesh(clampf(progress, 0.0, 1.0))
	_update_turning_hand_grip(clampf(progress, 0.0, 1.0))
	if progress >= 0.5 and not _turn_midpoint_emitted:
		_turn_midpoint_emitted = true
		page_turn_midpoint_reached.emit()


func _finish_page_turn() -> void:
	_turn_tween = null
	if not _turn_midpoint_emitted:
		_turn_midpoint_emitted = true
		page_turn_midpoint_reached.emit()
	_turning_page.visible = false
	_left_page.visible = true
	_right_page.visible = true
	_restore_hand_grips()
	page_turn_finished.emit()


func _set_open(open: bool) -> void:
	if _closed_visual != null:
		_closed_visual.visible = not open
	if _open_visual != null:
		_open_visual.visible = open


func _set_reading_motion_active(active: bool) -> void:
	_reading_active = active
	set_process(active)
	if not active and _motion_root != null:
		_motion_root.position = Vector3.ZERO
		_motion_root.rotation = Vector3.ZERO


func _apply_pose(marker: Marker3D) -> void:
	if _visual_root == null or marker == null:
		return
	_visual_root.transform = marker.transform


func _tween_to_pose(
		marker: Marker3D,
		close_when_finished: bool = false,
		settle: bool = false) -> void:
	if _visual_root == null or marker == null:
		if close_when_finished:
			_set_open(false)
		return
	_kill_pose_tween()
	_pose_tween = create_tween()
	_pose_tween.set_parallel(true)
	var transition := Tween.TRANS_BACK if settle else Tween.TRANS_QUAD
	_pose_tween.tween_property(_visual_root, "position", marker.position, pose_transition_seconds) \
		.set_trans(transition).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_visual_root, "quaternion", marker.quaternion, pose_transition_seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_visual_root, "scale", marker.scale, pose_transition_seconds) \
		.set_trans(transition).set_ease(Tween.EASE_OUT)
	if close_when_finished:
		_pose_tween.chain().tween_callback(_finish_closing_held)


func _finish_closing_held() -> void:
	if not _opening_held:
		_set_open(false)


func _kill_pose_tween() -> void:
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	_pose_tween = null


func _create_materials() -> void:
	_page_material = StandardMaterial3D.new()
	_page_material.albedo_color = Color.WHITE
	_page_material.roughness = 0.94
	_page_material.metallic = 0.0
	_page_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_page_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_page_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_page_material.albedo_texture = _page_texture

	_page_stack_material = StandardMaterial3D.new()
	_page_stack_material.albedo_color = Color(0.84, 0.69, 0.39)
	_page_stack_material.roughness = 0.97


func _rebuild_page_geometry() -> void:
	if not is_node_ready() or _profile == null:
		return
	_left_page.mesh = _build_resting_page_mesh(-1)
	_right_page.mesh = _build_resting_page_mesh(1)
	_left_page.material_override = _page_material
	_right_page.material_override = _page_material
	_turning_page.material_override = _page_material
	_configure_page_stack(_left_page_stack, -1)
	_configure_page_stack(_right_page_stack, 1)
	_turning_page.visible = false


func _build_resting_page_mesh(side: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := maxi(_profile.page_segments, 2)
	for segment in segments:
		var start_t := float(segment) / float(segments)
		var end_t := float(segment + 1) / float(segments)
		_add_page_quad(surface, side, start_t, end_t, false, 0.0)
	surface.generate_normals()
	return surface.commit()


func _build_turning_page_mesh(progress: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := maxi(_profile.page_segments, 2)
	for segment in segments:
		var start_t := float(segment) / float(segments)
		var end_t := float(segment + 1) / float(segments)
		_add_page_quad(surface, _turn_direction, start_t, end_t, true, progress)
	surface.generate_normals()
	return surface.commit()


func _add_page_quad(
		surface: SurfaceTool,
		side: int,
		start_t: float,
		end_t: float,
		turning: bool,
		progress: float) -> void:
	var half_height := _profile.spread_size.y * 0.5
	var vertices := [
		_page_vertex(side, start_t, -half_height, turning, progress),
		_page_vertex(side, end_t, -half_height, turning, progress),
		_page_vertex(side, end_t, half_height, turning, progress),
		_page_vertex(side, start_t, half_height, turning, progress),
	]
	var uvs := [
		_page_uv(side, start_t, 1.0),
		_page_uv(side, end_t, 1.0),
		_page_uv(side, end_t, 0.0),
		_page_uv(side, start_t, 0.0),
	]
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_uv(uvs[index] as Vector2)
		surface.add_vertex(vertices[index] as Vector3)


func _page_vertex(
		side: int,
		distance_ratio: float,
		z: float,
		turning: bool,
		progress: float) -> Vector3:
	var page_width := (_profile.spread_size.x - _profile.spine_gap) * 0.5
	var radius := _profile.spine_gap * 0.5 + page_width * distance_ratio
	if not turning:
		var resting_y := _profile.page_curve_height * pow(1.0 - distance_ratio, 2.0)
		return Vector3(float(side) * radius, resting_y, z)
	var base_angle := PI * progress
	var curl_angle := sin(PI * progress) * sin(PI * distance_ratio) * 0.34
	var angle := base_angle + curl_angle
	return Vector3(
		float(side) * radius * cos(angle),
		absf(radius * sin(angle)) + 0.001,
		z)


func _page_uv(side: int, distance_ratio: float, v: float) -> Vector2:
	var u := 0.5 + float(side) * distance_ratio * 0.5
	return Vector2(u, v)


func _configure_page_stack(stack: MeshInstance3D, side: int) -> void:
	if stack == null:
		return
	var page_width := (_profile.spread_size.x - _profile.spine_gap) * 0.5
	var filled_ratio := _page_progress_ratio if side < 0 else 1.0 - _page_progress_ratio
	var thickness := _profile.page_stack_thickness * lerpf(0.18, 1.0, filled_ratio)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(page_width, thickness, _profile.spread_size.y)
	stack.mesh = mesh
	stack.position = Vector3(
		float(side) * (_profile.spine_gap * 0.5 + page_width * 0.5),
		-thickness * 0.5,
		0.0)
	stack.material_override = _page_stack_material


func _configure_audio() -> void:
	if _profile == null:
		return
	if _open_audio != null:
		_open_audio.stream = _profile.open_sound
	if _close_audio != null:
		_close_audio.stream = _profile.close_sound
	if _page_audio != null:
		_page_audio.stream = _profile.page_turn_sound


func _restore_hand_grips() -> void:
	if _profile == null:
		return
	if _left_hand_grip != null:
		_left_hand_grip.transform = _profile.left_hand_grip
	if _right_hand_grip != null:
		_right_hand_grip.transform = _profile.right_hand_grip


func _update_turning_hand_grip(progress: float) -> void:
	if _motion_root == null or _page_surface == null or _profile == null:
		return
	var grip := _right_hand_grip if _turn_direction > 0 else _left_hand_grip
	if grip == null:
		return
	var page_point := _page_vertex(
		_turn_direction,
		0.88,
		_profile.spread_size.y * 0.28,
		true,
		progress)
	grip.position = _motion_root.to_local(_page_surface.to_global(page_point))


func _play_audio(player: AudioStreamPlayer3D, stream: AudioStream) -> void:
	if player == null or stream == null:
		return
	player.stream = stream
	player.pitch_scale = randf_range(0.96, 1.04)
	player.play()


func _replace_model(
		socket: Node3D,
		model_scene: PackedScene,
		model_transform: Transform3D,
		model_name: StringName) -> void:
	if socket == null:
		return
	for child in socket.get_children():
		socket.remove_child(child)
		child.queue_free()
	if model_scene == null:
		return
	var model := model_scene.instantiate() as Node3D
	if model == null:
		push_warning("Book visual profile model scene must have a Node3D root.")
		return
	model.name = model_name
	socket.add_child(model)
	model.transform = model_transform
