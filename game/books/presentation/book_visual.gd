class_name BookVisual
extends Node3D

signal page_turn_midpoint_reached
signal page_turn_finished

const PAGE_STACK_COLOR := Color(0.84, 0.69, 0.39)
const PAGE_STACK_TOP_CLEARANCE := 0.0008
const ORIGINAL_ALBEDO_META := &"book_original_albedo"
const JOURNAL_SURFACE_SHADER: Shader = preload(
	"res://game/books/presentation/journal_surface.gdshader")

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
var _open_tween: Tween
var _opening_held: bool = false
var _reading_active: bool = false
var _close_focused: bool = false
var _turn_direction: int = 1
var _turn_midpoint_emitted: bool = false
var _profile: BookVisualProfile
var _page_texture: Texture2D
var _page_material: StandardMaterial3D
var _right_page_material: StandardMaterial3D
var _turning_front_material: StandardMaterial3D
var _turning_back_material: StandardMaterial3D
var _page_stack_material: StandardMaterial3D
var _book_open_amount: float = 1.0
var _page_progress_ratio: float = 0.5
var _settled_page_progress_ratio: float = 0.5
var _turn_start_page_progress_ratio: float = 0.5
var _turn_target_page_progress_ratio: float = 0.5


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
	_configure_lighting_response()
	_set_reading_motion_active(_reading_active)


func get_visual_profile() -> BookVisualProfile:
	return _profile


func set_page_texture(texture: Texture2D) -> void:
	_page_texture = texture
	if _page_material != null:
		_page_material.albedo_texture = texture
	if _right_page_material != null:
		_right_page_material.albedo_texture = texture
	if _turning_front_material != null:
		_turning_front_material.albedo_texture = texture
	if _turning_back_material != null:
		_turning_back_material.albedo_texture = texture
	_rebuild_page_geometry()


func set_page_progress(spread_index: int, spread_count: int) -> void:
	_settled_page_progress_ratio = 0.5 if spread_count <= 1 else clampf(
		float(spread_index) / float(spread_count - 1),
		0.0,
		1.0)
	if _turn_tween == null:
		_apply_page_progress_ratio(_settled_page_progress_ratio)


func show_world_closed() -> void:
	_opening_held = false
	_set_reading_motion_active(false)
	_close_focused = false
	cancel_page_turn()
	_kill_pose_tween()
	_kill_open_tween()
	_set_book_open_amount(0.0)
	_apply_pose(_world_pose)
	_set_open(false)


func show_held_closed() -> void:
	_opening_held = false
	_set_reading_motion_active(false)
	_close_focused = false
	cancel_page_turn()
	_kill_pose_tween()
	_kill_open_tween()
	_set_book_open_amount(0.0)
	_apply_pose(_held_pose)
	_set_open(false)


func open_held() -> void:
	_opening_held = true
	_set_reading_motion_active(true)
	_close_focused = false
	_kill_open_tween()
	_set_book_open_amount(0.0)
	_set_open(true)
	_play_audio(_open_audio, _profile.open_sound if _profile != null else null)
	_tween_to_pose(_reading_pose, false, true)
	_tween_book_open_amount(1.0)


func close_held() -> void:
	_opening_held = false
	_set_reading_motion_active(false)
	_close_focused = false
	cancel_page_turn()
	_play_audio(_close_audio, _profile.close_sound if _profile != null else null)
	_tween_to_pose(_held_pose, true)
	_tween_book_open_amount(0.0)


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


## Converts a screen-space pointer into the normalized UV used by the complete
## two-page spread. A short iteration follows the curved page surface so the
## clickable area remains aligned with the rendered paper.
func page_uv_from_screen(camera: Camera3D, screen_position: Vector2) -> Vector2:
	if camera == null or _page_surface == null or _profile == null:
		return Vector2(-1.0, -1.0)
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var local_origin := _page_surface.to_local(ray_origin)
	var local_direction := _page_surface.global_basis.inverse() * ray_direction
	if absf(local_direction.y) <= 0.00001:
		return Vector2(-1.0, -1.0)
	var distance := -local_origin.y / local_direction.y
	var hit := local_origin + local_direction * distance
	for iteration in 3:
		var expected_height := _page_surface_height(hit.x)
		distance = (expected_height - local_origin.y) / local_direction.y
		hit = local_origin + local_direction * distance
	if distance < 0.0:
		return Vector2(-1.0, -1.0)
	var half_width := _profile.spread_size.x * 0.5
	var half_height := _profile.spread_size.y * 0.5
	if absf(hit.x) > half_width or absf(hit.z) > half_height:
		return Vector2(-1.0, -1.0)
	return Vector2(
		(hit.x + half_width) / _profile.spread_size.x,
		(half_height - hit.z) / _profile.spread_size.y)


func page_uv_to_screen(camera: Camera3D, page_uv: Vector2) -> Vector2:
	if camera == null or _page_surface == null or _profile == null:
		return Vector2(-1.0, -1.0)
	var local_point := Vector3(
		(page_uv.x - 0.5) * _profile.spread_size.x,
		0.0,
		(0.5 - page_uv.y) * _profile.spread_size.y)
	local_point.y = _page_surface_height(local_point.x)
	return camera.unproject_position(_page_surface.to_global(local_point))


func _page_surface_height(local_x: float) -> float:
	var page_width := (_profile.spread_size.x - _profile.spine_gap) * 0.5
	var distance_ratio := clampf(
		(absf(local_x) - _profile.spine_gap * 0.5) / page_width,
		0.0,
		1.0)
	return _resting_page_height(distance_ratio)


func show_table_open() -> void:
	_opening_held = false
	_set_reading_motion_active(false)
	_close_focused = false
	cancel_page_turn()
	_kill_pose_tween()
	_kill_open_tween()
	_set_book_open_amount(1.0)
	_apply_pose(_table_pose)
	_set_open(true)


func play_page_turn(
		direction: int,
		outgoing_texture: Texture2D = null,
		destination_texture: Texture2D = null,
		destination_progress_ratio: float = -1.0) -> bool:
	if _profile == null or _turning_page == null or _turn_tween != null:
		return false
	_turn_direction = 1 if direction >= 0 else -1
	_turn_midpoint_emitted = false
	_turn_start_page_progress_ratio = _page_progress_ratio
	_turn_target_page_progress_ratio = clampf(
		destination_progress_ratio, 0.0, 1.0) \
		if destination_progress_ratio >= 0.0 else _page_progress_ratio
	_turning_page.visible = true
	# Keep both resting pages underneath the moving sheet. Independent source
	# and destination textures let the moving sheet reveal the target naturally.
	_left_page.visible = true
	_right_page.visible = true
	_configure_turn_textures(outgoing_texture, destination_texture)
	_set_page_turn_progress(0.0)
	_play_audio(_page_audio, _profile.page_turn_sound)
	_turn_tween = create_tween()
	_turn_tween.tween_method(
		_set_page_turn_progress,
		0.0,
		1.0,
		_profile.page_turn_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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
	_restore_page_textures()
	_restore_hand_grips()
	_apply_page_progress_ratio(_settled_page_progress_ratio)


func _set_page_turn_progress(progress: float) -> void:
	if _turning_page == null or _profile == null:
		return
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var stack_progress := smoothstep(0.0, 1.0, clamped_progress)
	_apply_page_progress_ratio(lerpf(
		_turn_start_page_progress_ratio,
		_turn_target_page_progress_ratio,
		stack_progress))
	_turning_page.mesh = _build_turning_page_mesh(clamped_progress)
	_apply_turning_page_materials()
	_update_turning_hand_grip(clamped_progress)
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
	_restore_page_textures()
	_restore_hand_grips()
	_apply_page_progress_ratio(_settled_page_progress_ratio)
	page_turn_finished.emit()


func _set_open(open: bool) -> void:
	if _closed_visual != null:
		_closed_visual.visible = not open
	if _open_visual != null:
		_open_visual.visible = open


func _set_reading_motion_active(active: bool) -> void:
	_reading_active = active
	var has_motion := active and _profile != null \
		and (_profile.breathing_lift > 0.0 or _profile.sway_degrees > 0.0)
	set_process(has_motion)
	if not has_motion and _motion_root != null:
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
		_set_book_open_amount(0.0)
		_set_open(false)


func _kill_pose_tween() -> void:
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	_pose_tween = null


func _tween_book_open_amount(target: float) -> void:
	if _profile == null:
		_set_book_open_amount(target)
		return
	_kill_open_tween()
	_open_tween = create_tween()
	_open_tween.tween_method(
		_set_book_open_amount,
		_book_open_amount,
		clampf(target, 0.0, 1.0),
		_profile.book_open_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _kill_open_tween() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = null


func _set_book_open_amount(amount: float) -> void:
	_book_open_amount = clampf(amount, 0.0, 1.0)
	if _open_model_socket != null and _profile != null:
		var eased_open := smoothstep(0.0, 1.0, _book_open_amount)
		var closed_width := sin(deg_to_rad(_profile.closed_book_angle_degrees))
		_open_model_socket.scale = Vector3(
			lerpf(closed_width, 1.0, eased_open), 1.0, 1.0)
	if is_node_ready() and _profile != null:
		_rebuild_resting_page_geometry()


func _create_materials() -> void:
	_page_material = StandardMaterial3D.new()
	_page_material.albedo_color = Color.WHITE
	_page_material.roughness = 0.94
	_page_material.metallic = 0.0
	_page_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_page_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_page_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_page_material.vertex_color_use_as_albedo = true
	_page_material.albedo_texture = _page_texture
	_right_page_material = _page_material.duplicate() as StandardMaterial3D
	_turning_front_material = _page_material.duplicate() as StandardMaterial3D
	_turning_front_material.cull_mode = BaseMaterial3D.CULL_BACK
	_turning_back_material = _turning_front_material.duplicate() as StandardMaterial3D

	_page_stack_material = StandardMaterial3D.new()
	_page_stack_material.albedo_color = PAGE_STACK_COLOR
	_page_stack_material.roughness = 0.97
	_page_stack_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_page_stack_material.vertex_color_use_as_albedo = true


func _rebuild_page_geometry() -> void:
	if not is_node_ready() or _profile == null:
		return
	_rebuild_resting_page_geometry()
	_turning_page.material_override = null
	_apply_turning_page_materials()
	_turning_page.visible = false


func _rebuild_resting_page_geometry() -> void:
	if _profile == null:
		return
	_left_page.mesh = _build_resting_page_mesh(-1)
	_right_page.mesh = _build_resting_page_mesh(1)
	_left_page.material_override = _page_material
	_right_page.material_override = _right_page_material
	_configure_page_stack(_left_page_stack, -1)
	_configure_page_stack(_right_page_stack, 1)


func _apply_page_progress_ratio(progress_ratio: float) -> void:
	_page_progress_ratio = clampf(progress_ratio, 0.0, 1.0)
	if is_node_ready() and _profile != null:
		# The readable sheets stay on one stable plane. Only the page blocks
		# underneath them change depth as paper transfers between sides.
		_configure_page_stack(_left_page_stack, -1)
		_configure_page_stack(_right_page_stack, 1)


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
	var front_surface := SurfaceTool.new()
	front_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var back_surface := SurfaceTool.new()
	back_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := maxi(_profile.page_segments, 2)
	for segment in segments:
		var start_t := float(segment) / float(segments)
		var end_t := float(segment + 1) / float(segments)
		_add_page_quad(
			front_surface, _turn_direction, start_t, end_t, true, progress, false)
		_add_page_quad(
			back_surface, _turn_direction, start_t, end_t, true, progress, true)
	front_surface.generate_normals()
	var mesh := front_surface.commit()
	back_surface.generate_normals()
	back_surface.commit(mesh)
	return mesh


func _add_page_quad(
		surface: SurfaceTool,
		side: int,
		start_t: float,
		end_t: float,
		turning: bool,
		progress: float,
		back_face: bool = false) -> void:
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
	var distance_ratios := [start_t, end_t, end_t, start_t]
	# Increasing distance moves toward +X on a forward turn and toward -X on a
	# reverse turn. Swap winding with the direction so surface 0 remains the
	# outgoing front and surface 1 remains the destination back in both cases.
	var reverse_winding := back_face != (side < 0)
	var indices := [0, 3, 2, 0, 2, 1] \
		if reverse_winding else [0, 1, 2, 0, 2, 3]
	for index in indices:
		var uv := uvs[index] as Vector2
		if back_face:
			uv.x = 1.0 - uv.x
		surface.set_uv(uv)
		surface.set_color(_page_vertex_color(
			distance_ratios[index] as float, turning, progress))
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
		return _fold_open_page_point(Vector3(
			float(side) * radius,
			_resting_page_height(distance_ratio),
			z))
	var cross_section := _turning_page_cross_section(distance_ratio, progress)
	var resting_y := _resting_page_height(distance_ratio)
	var resting_blend := maxf(
		1.0 - smoothstep(0.0, 0.18, progress),
		smoothstep(0.82, 1.0, progress))
	return Vector3(
		float(side) * cross_section.x,
		cross_section.y + resting_y * resting_blend + 0.001,
		z)


func _resting_page_height(distance_ratio: float) -> float:
	return -_profile.page_curve_height * pow(1.0 - distance_ratio, 2.0)


func _fold_open_page_point(point: Vector3) -> Vector3:
	if _profile == null or _book_open_amount >= 0.9999:
		return point
	var side := -1.0 if point.x < 0.0 else 1.0
	var hinge_x := side * _profile.spine_gap * 0.5
	var offset_x := point.x - hinge_x
	var eased_open := smoothstep(0.0, 1.0, _book_open_amount)
	var open_angle := lerpf(
		deg_to_rad(_profile.closed_book_angle_degrees),
		PI * 0.5,
		eased_open)
	var fold_angle := side * (PI * 0.5 - open_angle)
	var fold_cos := cos(fold_angle)
	var fold_sin := sin(fold_angle)
	return Vector3(
		hinge_x + offset_x * fold_cos - point.y * fold_sin,
		offset_x * fold_sin + point.y * fold_cos,
		point.z)


## Integrates the page's tangent across its width. Unlike rotating each vertex
## around the spine independently, this preserves a continuous sheet while
## allowing the free edge to curl farther than the bound edge.
func _turning_page_cross_section(distance_ratio: float, progress: float) -> Vector2:
	var base_angle := PI * progress
	var spine_radius := _profile.spine_gap * 0.5
	var point := Vector2(cos(base_angle), sin(base_angle)) * spine_radius
	if distance_ratio <= 0.0:
		return point
	var page_width := (_profile.spread_size.x - _profile.spine_gap) * 0.5
	var integration_steps := maxi(1, ceili(float(_profile.page_segments) * distance_ratio))
	var step_length := page_width * distance_ratio / float(integration_steps)
	var curl_strength := deg_to_rad(_profile.page_turn_curl_degrees) \
		* sin(PI * progress)
	for step in integration_steps:
		var sheet_ratio := distance_ratio * (float(step) + 0.5) \
			/ float(integration_steps)
		var curl_angle := curl_strength * sin(sheet_ratio * PI * 0.5)
		# Never let the free edge roll through the destination page. Crossing PI
		# exposes the outgoing front again just before landing and reads as a pop.
		var tangent_angle := clampf(base_angle + curl_angle, 0.0, PI)
		point += Vector2(cos(tangent_angle), sin(tangent_angle)) * step_length
	return point


func _page_vertex_color(
		distance_ratio: float,
		turning: bool,
		progress: float) -> Color:
	var spine_shade := lerpf(0.82, 1.0, smoothstep(0.0, 0.22, distance_ratio))
	var turn_shadow := 0.0
	if turning:
		turn_shadow = _profile.page_turn_shadow_strength \
			* sin(PI * progress) \
			* pow(sin(PI * distance_ratio), 2.0)
	var shade := clampf(spine_shade - turn_shadow, 0.5, 1.0)
	return Color(shade, shade, shade, 1.0)


func _page_uv(side: int, distance_ratio: float, v: float) -> Vector2:
	var u := 0.5 + float(side) * distance_ratio * 0.5
	return Vector2(u, v)


func _configure_page_stack(stack: MeshInstance3D, side: int) -> void:
	if stack == null:
		return
	var thickness := _page_stack_thickness(side)
	stack.mesh = _build_page_stack_mesh(side, thickness)
	stack.position = Vector3.ZERO
	stack.material_override = _page_stack_material


func _build_page_stack_mesh(side: int, thickness: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := maxi(_profile.page_segments, 2)
	var half_height := _profile.spread_size.y * 0.5
	var page_width := (_profile.spread_size.x - _profile.spine_gap) * 0.5
	var page_layers := 8
	for segment in segments:
		var start_t := float(segment) / float(segments)
		var end_t := float(segment + 1) / float(segments)
		var start_x := float(side) * (_profile.spine_gap * 0.5 + page_width * start_t)
		var end_x := float(side) * (_profile.spine_gap * 0.5 + page_width * end_t)
		var start_top := _resting_page_height(start_t) - PAGE_STACK_TOP_CLEARANCE
		var end_top := _resting_page_height(end_t) - PAGE_STACK_TOP_CLEARANCE
		_add_stack_quad(surface,
			Vector3(start_x, start_top, -half_height),
			Vector3(end_x, end_top, -half_height),
			Vector3(end_x, end_top, half_height),
			Vector3(start_x, start_top, half_height),
			0.98)
		for layer in page_layers:
			var layer_start := float(layer) / float(page_layers)
			var layer_end := float(layer + 1) / float(page_layers)
			var start_layer_top := start_top - thickness * layer_start
			var start_layer_bottom := start_top - thickness * layer_end
			var end_layer_top := end_top - thickness * layer_start
			var end_layer_bottom := end_top - thickness * layer_end
			var layer_variation := 0.84 + 0.11 * (
				sin(float(layer * 17 + segment * 7)) * 0.5 + 0.5)
			_add_stack_quad(surface,
				Vector3(start_x, start_layer_bottom, -half_height),
				Vector3(start_x, start_layer_top, -half_height),
				Vector3(end_x, end_layer_top, -half_height),
				Vector3(end_x, end_layer_bottom, -half_height),
				layer_variation)
			_add_stack_quad(surface,
				Vector3(end_x, end_layer_bottom, half_height),
				Vector3(end_x, end_layer_top, half_height),
				Vector3(start_x, start_layer_top, half_height),
				Vector3(start_x, start_layer_bottom, half_height),
				layer_variation * 0.96)
			if segment == 0:
				_add_stack_quad(surface,
					Vector3(start_x, start_layer_bottom, half_height),
					Vector3(start_x, start_layer_top, half_height),
					Vector3(start_x, start_layer_top, -half_height),
					Vector3(start_x, start_layer_bottom, -half_height),
					layer_variation * 0.9)
			if segment == segments - 1:
				_add_stack_quad(surface,
					Vector3(end_x, end_layer_bottom, -half_height),
					Vector3(end_x, end_layer_top, -half_height),
					Vector3(end_x, end_layer_top, half_height),
					Vector3(end_x, end_layer_bottom, half_height),
					layer_variation)
	surface.generate_normals()
	return surface.commit()


func _page_stack_thickness(side: int) -> float:
	return _page_stack_thickness_at(side, _page_progress_ratio)


func _page_stack_thickness_at(side: int, progress_ratio: float) -> float:
	var filled_ratio := progress_ratio if side < 0 else 1.0 - progress_ratio
	return _profile.page_stack_thickness * lerpf(
		_profile.minimum_page_stack_ratio,
		1.0,
		clampf(filled_ratio, 0.0, 1.0))


func _add_stack_quad(
		surface: SurfaceTool,
		a: Vector3,
		b: Vector3,
		c: Vector3,
		d: Vector3,
		shade: float = 1.0) -> void:
	for vertex in [a, b, c, a, c, d]:
		surface.set_color(Color(shade, shade, shade, 1.0))
		surface.add_vertex(_fold_open_page_point(vertex))


func _configure_audio() -> void:
	if _profile == null:
		return
	if _open_audio != null:
		_open_audio.stream = _profile.open_sound
	if _close_audio != null:
		_close_audio.stream = _profile.close_sound
	if _page_audio != null:
		_page_audio.stream = _profile.page_turn_sound


func _configure_lighting_response() -> void:
	if _profile == null:
		return
	var shading_mode := BaseMaterial3D.SHADING_MODE_UNSHADED \
		if _profile.unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var draws_over_world := _profile.unshaded
	_page_material.albedo_color = _profile.albedo_tint
	_right_page_material.albedo_color = _profile.albedo_tint
	_turning_front_material.albedo_color = _profile.albedo_tint
	_turning_back_material.albedo_color = _profile.albedo_tint
	_page_stack_material.albedo_color = PAGE_STACK_COLOR * _profile.albedo_tint
	_page_material.shading_mode = shading_mode
	_right_page_material.shading_mode = shading_mode
	_turning_front_material.shading_mode = shading_mode
	_turning_back_material.shading_mode = shading_mode
	_page_stack_material.shading_mode = shading_mode
	_page_material.no_depth_test = draws_over_world
	_right_page_material.no_depth_test = draws_over_world
	_turning_front_material.no_depth_test = draws_over_world
	_turning_back_material.no_depth_test = draws_over_world
	_page_stack_material.no_depth_test = draws_over_world
	_page_material.render_priority = 100 if draws_over_world else 0
	_right_page_material.render_priority = 100 if draws_over_world else 0
	_page_stack_material.render_priority = 90 if draws_over_world else 0
	_turning_front_material.render_priority = 110 if draws_over_world else 0
	_turning_back_material.render_priority = 110 if draws_over_world else 0
	for node in _visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance in [
				_left_page,
				_right_page,
				_left_page_stack,
				_right_page_stack,
				_turning_page,
			]:
			continue
		_set_mesh_lighting_response(
			mesh_instance, shading_mode, _profile.albedo_tint, draws_over_world)


func _configure_turn_textures(
		outgoing_texture: Texture2D,
		destination_texture: Texture2D) -> void:
	var outgoing := outgoing_texture if outgoing_texture != null else _page_texture
	var destination := destination_texture if destination_texture != null else _page_texture
	if _turn_direction > 0:
		_page_material.albedo_texture = outgoing
		_right_page_material.albedo_texture = destination
	else:
		_page_material.albedo_texture = destination
		_right_page_material.albedo_texture = outgoing
	_turning_front_material.albedo_texture = outgoing
	_turning_back_material.albedo_texture = destination
	_apply_turning_page_materials()


func _restore_page_textures() -> void:
	if _page_texture == null:
		return
	_page_material.albedo_texture = _page_texture
	_right_page_material.albedo_texture = _page_texture
	_turning_front_material.albedo_texture = _page_texture
	_turning_back_material.albedo_texture = _page_texture


func _apply_turning_page_materials() -> void:
	if _turning_page == null or _turning_page.mesh == null:
		return
	_turning_page.set_surface_override_material(0, _turning_front_material)
	if _turning_page.mesh.get_surface_count() > 1:
		_turning_page.set_surface_override_material(1, _turning_back_material)


func _set_mesh_lighting_response(
		mesh_instance: MeshInstance3D,
		shading_mode: BaseMaterial3D.ShadingMode,
		albedo_tint: Color,
		draws_over_world: bool) -> void:
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	if draws_over_world:
		_set_journal_surface_materials(mesh_instance, albedo_tint)
		return
	if mesh_instance.material_override is BaseMaterial3D:
		var override := mesh_instance.material_override.duplicate() as BaseMaterial3D
		override.shading_mode = shading_mode
		override.no_depth_test = draws_over_world
		override.render_priority = 80 if draws_over_world else 0
		_tint_material_from_original(override, albedo_tint)
		mesh_instance.material_override = override
		return
	var mesh_copy := mesh_instance.mesh.duplicate(true) as Mesh
	var changed := false
	for surface in mesh_instance.mesh.get_surface_count():
		var material := mesh_instance.mesh.surface_get_material(surface)
		if material is not BaseMaterial3D:
			continue
		var surface_material := material.duplicate() as BaseMaterial3D
		surface_material.shading_mode = shading_mode
		surface_material.no_depth_test = draws_over_world
		surface_material.render_priority = 80 if draws_over_world else 0
		_tint_material_from_original(surface_material, albedo_tint)
		mesh_copy.surface_set_material(surface, surface_material)
		changed = true
	if changed:
		mesh_instance.mesh = mesh_copy


func _set_journal_surface_materials(
		mesh_instance: MeshInstance3D,
		albedo_tint: Color) -> void:
	if mesh_instance.material_override is BaseMaterial3D:
		mesh_instance.material_override = _create_journal_surface_material(
			mesh_instance.material_override as BaseMaterial3D, albedo_tint)
		return
	for surface in mesh_instance.mesh.get_surface_count():
		var source := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
		if source == null:
			continue
		mesh_instance.set_surface_override_material(
			surface, _create_journal_surface_material(source, albedo_tint))


func _create_journal_surface_material(
		source: BaseMaterial3D,
		albedo_tint: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = JOURNAL_SURFACE_SHADER
	material.render_priority = 80
	var surface_kind := _journal_surface_kind(source)
	var tint_strength := 0.08 if surface_kind == 2 else 0.18
	var gentle_tint := Color.WHITE.lerp(albedo_tint, tint_strength)
	var base_color := source.albedo_color * gentle_tint
	if surface_kind == 0:
		# Imported closed covers are much more saturated than the open model.
		# Pull both into one worn oxblood-leather range for the belt animation.
		base_color = base_color.lerp(Color(0.16, 0.055, 0.03), 0.68)
	elif surface_kind == 1:
		base_color = base_color.lerp(Color(0.52, 0.43, 0.29), 0.24)
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("surface_kind", surface_kind)
	material.set_shader_parameter("wear_strength", 0.68 if surface_kind == 0 else 0.42)
	return material


func _journal_surface_kind(material: BaseMaterial3D) -> int:
	var material_name := material.resource_name.to_lower()
	if "brass" in material_name or "metal" in material_name:
		return 2
	if "thread" in material_name or "stitch" in material_name:
		return 3
	if "parchment" in material_name or "page" in material_name:
		return 1
	if "leather" in material_name or "cover" in material_name:
		return 0
	return 1 if material.albedo_color.get_luminance() > 0.42 else 0


func _tint_material_from_original(material: BaseMaterial3D, tint: Color) -> void:
	if not material.has_meta(ORIGINAL_ALBEDO_META):
		material.set_meta(ORIGINAL_ALBEDO_META, material.albedo_color)
	var original := material.get_meta(ORIGINAL_ALBEDO_META) as Color
	material.albedo_color = original * tint


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
