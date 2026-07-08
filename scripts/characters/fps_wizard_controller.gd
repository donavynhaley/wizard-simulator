extends CharacterBody3D

@export var move_speed: float = 4.2
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.0022
@export var acceleration: float = 16.0
@export var deceleration: float = 12.0

@export_group("Stair Stepping")
@export var enable_stair_stepping: bool = true
@export var max_step_height: float = 0.8
@export var min_step_height: float = 0.08
@export var step_probe_clearance: float = 0.35
@export var step_forward_distance: float = 0.5
@export var step_down_extra: float = 0.08
@export var step_down_snap_height: float = 0.5
@export var stair_floor_snap_length: float = 0.45
@export_range(0.1, 1.0, 0.01) var stair_climb_speed_multiplier: float = 0.72
@export var stair_step_feedback_time: float = 0.32
@export var stair_camera_lift_amount: float = 0.045
@export var stair_camera_pitch_degrees: float = 1.8
@export var stair_camera_step_smoothing: float = 5.0
@export var debug_stair_stepping: bool = false

@export_group("Viewmodel Placement")
@export var viewmodel_rest_position: Vector3 = Vector3(0.0, -0.5, -0.55)
@export var wizard_body_position: Vector3 = Vector3(0.0, -0.84, 0.0)
@export var wizard_body_rotation_degrees: Vector3 = Vector3(0.0, 180.0, 0.0)
@export var wizard_body_scale: Vector3 = Vector3.ONE
@export var body_local_head_cut: float = 0.035
@export var body_local_arm_side_cut: float = 0.027
@export var body_local_arm_height_cut: float = 0.064
@export var body_visible_pitch_degrees: float = -35.0
@export var arm_pitch_follow: float = 0.45

@export_group("Water Hold Pose")
@export var water_hold_blend_speed: float = 7.0
@export var water_hold_body_position_offset: Vector3 = Vector3(0.0, 0.015, 0.0)

@export_group("First Person Model Arms")
@export var show_first_person_model_arms: bool = true
@export var left_model_arm_rest_position: Vector3 = Vector3(-0.20, -1.72, -0.86)
@export var right_model_arm_rest_position: Vector3 = Vector3(0.20, -1.72, -0.86)
@export var left_model_arm_water_position: Vector3 = Vector3(-0.08, -1.62, -0.78)
@export var right_model_arm_water_position: Vector3 = Vector3(0.08, -1.62, -0.78)
@export var model_arm_rest_rotation_degrees: Vector3 = Vector3(-28.0, 180.0, 0.0)
@export var model_arm_water_rotation_degrees: Vector3 = Vector3(-34.0, 180.0, 0.0)
@export var model_arm_scale: float = 1.0

@export_group("Viewmodel Motion")
@export var walk_bob_amount: float = 0.012
@export var walk_sway_amount: float = 0.006
@export var idle_breathe_amount: float = 0.01
@export var idle_drift_amount: float = 0.006
@export var look_sway_position_amount: float = 0.00045
@export var look_sway_rotation_amount: float = 0.045
@export var look_sway_return_speed: float = 9.0

const WIZARD_BODY_SCENE := preload("res://assets/artifacts/player_wizard.tscn")
const LEFT_ARM_BASE_ROTATION := Quaternion(-0.023753023, -0.006342602, -0.48897812, 0.87194955)
const LEFT_FOREARM_BASE_ROTATION := Quaternion(0.07219099, -0.348859, -0.26778162, 0.89519763)
const RIGHT_ARM_BASE_ROTATION := Quaternion(-0.023753023, 0.006342602, 0.48897812, 0.87194955)
const RIGHT_FOREARM_BASE_ROTATION := Quaternion(0.07219099, 0.348859, 0.26778162, 0.89519763)
const ALL_3D_RENDER_LAYERS := (1 << 20) - 1
const WORLD_RENDER_LAYER := 1 << 0
const LEFT_VIEWMODEL_ARM_BONES := [
	"DEF-ARM.L",
	"DEF-FOREARM.L",
	"DEF-HAND.L",
	"DEF-THUMB01.L",
	"DEF-THUMB02.L",
	"DEF-THUMB03.L",
	"DEF-FINGER01.L",
	"DEF-FINGER02.L",
	"DEF-FINGER03.L",
	"DEF-FOREARM-HANG01.L",
	"DEF-FOREARM-HANG02.L",
	"DEF-FOREARM-HANG03.L",
]

@onready var head: Node3D = $Head
@onready var viewmodel: Node3D = $Head/Camera3D/Viewmodel
@onready var camera: Camera3D = $Head/Camera3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _body: Node3D
var _body_skeleton: Skeleton3D
var _body_materials: Array[ShaderMaterial] = []
var _viewmodel_arms_root: Node3D
var _left_viewmodel_arm: Node3D
var _right_viewmodel_arm: Node3D
var _look_sway := Vector2.ZERO
var _look_sway_target := Vector2.ZERO
var _stair_step_timer := 0.0
var _stair_step_strength := 0.0
var _head_rest_position := Vector3.ZERO
var _body_rest_position := Vector3.ZERO
var _head_step_offset := 0.0
var _water_hold_target := 0.0
var _water_hold_blend := 0.0


func _ready() -> void:
	_capture_mouse()
	floor_snap_length = maxf(floor_snap_length, stair_floor_snap_length)
	_head_rest_position = head.position
	viewmodel.position = viewmodel_rest_position
	_mount_body()
	_mount_first_person_model_arms()
	var hands := get_node_or_null("%HandAnchor")
	if hands and hands.has_signal("held_changed"):
		hands.held_changed.connect(_on_held_changed)


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_MOUSE_ENTER:
			if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
				_capture_mouse()
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
				_capture_mouse()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
				_capture_mouse()


func _mount_body() -> void:
	camera.cull_mask = ALL_3D_RENDER_LAYERS

	_body = WIZARD_BODY_SCENE.instantiate()
	_body.name = "FirstPersonBody"
	_body.position = wizard_body_position
	_body.rotation_degrees = wizard_body_rotation_degrees
	_body.scale = wizard_body_scale
	add_child(_body)

	_body_rest_position = wizard_body_position
	_body_skeleton = _find_skeleton(_body)
	_set_visual_layer(_body, WORLD_RENDER_LAYER)
	if _body_skeleton:
		_pose_wizard_hands()
	_apply_body_material(_body)
	_update_body_materials()


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _pose_wizard_hands() -> void:
	if _body_skeleton == null:
		return
	var pitch_offset := Quaternion(Vector3.RIGHT, head.rotation.x * arm_pitch_follow)
	_set_bone_rotation("DEF-ARM.L", (pitch_offset * LEFT_ARM_BASE_ROTATION).normalized())
	_set_bone_rotation("DEF-FOREARM.L", (pitch_offset * LEFT_FOREARM_BASE_ROTATION).normalized())
	_set_bone_rotation("DEF-ARM.R", (pitch_offset * RIGHT_ARM_BASE_ROTATION).normalized())
	_set_bone_rotation("DEF-FOREARM.R", (pitch_offset * RIGHT_FOREARM_BASE_ROTATION).normalized())


func _set_bone_rotation(bone_name: String, rotation: Quaternion) -> void:
	var bone := _body_skeleton.find_bone(bone_name)
	if bone != -1:
		_body_skeleton.set_bone_pose_rotation(bone, rotation)


func _set_visual_layer(node: Node, layer_mask: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer_mask
	for child in node.get_children():
		_set_visual_layer(child, layer_mask)


func _apply_body_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_override = _body_material(mesh_instance)
	for child in node.get_children():
		_apply_body_material(child)


func _body_material(mesh_instance: MeshInstance3D) -> ShaderMaterial:
	var source_material := _source_mesh_material(mesh_instance)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float metallic = 0.0;
uniform float roughness = 1.0;
uniform float local_head_cut = 0.055;
uniform float local_arm_side_cut = 0.027;
uniform float local_arm_height_cut = 0.035;

varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	if (local_position.z > local_head_cut) {
		discard;
	}
	if (abs(local_position.x) > local_arm_side_cut && local_position.z > local_arm_height_cut) {
		discard;
	}

	vec4 tex = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader
	if source_material:
		material.set_shader_parameter("albedo_texture", source_material.albedo_texture)
		material.set_shader_parameter("albedo_color", source_material.albedo_color)
		material.set_shader_parameter("metallic", source_material.metallic)
		material.set_shader_parameter("roughness", source_material.roughness)
	material.set_shader_parameter("local_head_cut", body_local_head_cut)
	material.set_shader_parameter("local_arm_side_cut", body_local_arm_side_cut)
	material.set_shader_parameter("local_arm_height_cut", body_local_arm_height_cut)
	_body_materials.append(material)
	return material


func _source_mesh_material(mesh_instance: MeshInstance3D) -> BaseMaterial3D:
	var override_material := mesh_instance.get_active_material(0)
	if override_material is BaseMaterial3D:
		return override_material as BaseMaterial3D
	if mesh_instance.mesh and mesh_instance.mesh.get_surface_count() > 0:
		var surface_material := mesh_instance.mesh.surface_get_material(0)
		if surface_material is BaseMaterial3D:
			return surface_material as BaseMaterial3D
	return null


func _mount_first_person_model_arms() -> void:
	if not show_first_person_model_arms:
		return

	_viewmodel_arms_root = Node3D.new()
	_viewmodel_arms_root.name = "FirstPersonModelArms"
	viewmodel.add_child(_viewmodel_arms_root)

	_left_viewmodel_arm = _build_viewmodel_arm("LeftModelArm", false)
	_right_viewmodel_arm = _build_viewmodel_arm("RightModelArm", true)
	_update_first_person_model_arms()


func _build_viewmodel_arm(arm_name: String, mirrored: bool) -> Node3D:
	var arm := WIZARD_BODY_SCENE.instantiate()
	arm.name = arm_name
	arm.scale = Vector3(-model_arm_scale, model_arm_scale, model_arm_scale) \
		if mirrored else Vector3.ONE * model_arm_scale
	_viewmodel_arms_root.add_child(arm)

	var skeleton := _find_skeleton(arm)
	if skeleton:
		_filter_to_viewmodel_arm_meshes(arm, _bone_indices(skeleton, LEFT_VIEWMODEL_ARM_BONES))
		_set_viewmodel_materials(arm)
	return arm


func _filter_to_viewmodel_arm_meshes(node: Node, arm_indices: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.mesh = _filtered_arm_mesh(mesh_instance.mesh, arm_indices)
	for child in node.get_children():
		_filter_to_viewmodel_arm_meshes(child, arm_indices)


func _filtered_arm_mesh(source: Mesh, arm_indices: Dictionary) -> ArrayMesh:
	var filtered := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var source_indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var bones := arrays[Mesh.ARRAY_BONES] as PackedInt32Array
		var weights := arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
		var kept_indices := PackedInt32Array()

		for i in range(0, source_indices.size(), 3):
			var a := source_indices[i]
			var b := source_indices[i + 1]
			var c := source_indices[i + 2]
			if _arm_weight(a, bones, weights, arm_indices) >= 0.45 \
					and _arm_weight(b, bones, weights, arm_indices) >= 0.45 \
					and _arm_weight(c, bones, weights, arm_indices) >= 0.45:
				kept_indices.append(a)
				kept_indices.append(b)
				kept_indices.append(c)

		arrays[Mesh.ARRAY_INDEX] = kept_indices
		filtered.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		filtered.surface_set_material(surface, source.surface_get_material(surface))
	return filtered


func _arm_weight(
		vertex_index: int,
		bones: PackedInt32Array,
		weights: PackedFloat32Array,
		arm_indices: Dictionary) -> float:
	var total := 0.0
	var offset := vertex_index * 4
	for i in 4:
		if arm_indices.has(bones[offset + i]):
			total += weights[offset + i]
	return total


func _bone_indices(skeleton: Skeleton3D, bone_names: Array) -> Dictionary:
	var indices := {}
	for bone_name in bone_names:
		var bone := skeleton.find_bone(bone_name)
		if bone != -1:
			indices[bone] = true
	return indices


func _set_viewmodel_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in mesh_instance.mesh.get_surface_count():
			var source_material := mesh_instance.mesh.surface_get_material(surface)
			if source_material is BaseMaterial3D:
				var material := (source_material as BaseMaterial3D).duplicate()
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh_instance.set_surface_override_material(surface, material)
	for child in node.get_children():
		_set_viewmodel_materials(child)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			apply_mouse_look(event.relative)
		return

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_capture_mouse()


func apply_mouse_look(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	head.rotate_x(-relative.y * mouse_sensitivity)
	head.rotation.x = clamp(head.rotation.x, -PI * 0.48, PI * 0.48)
	_look_sway_target = relative
	_update_body_visibility()


func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()
	var position_before_move := global_position
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var pre_snapped_down := false

	if enable_stair_stepping \
			and not was_on_floor \
			and direction != Vector3.ZERO \
			and velocity.y <= 0.0:
		pre_snapped_down = _try_step_down()

	if not is_on_floor() and not pre_snapped_down:
		velocity.y -= _gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var climb_multiplier := stair_climb_speed_multiplier if _stair_step_timer > 0.0 else 1.0
	var target_velocity := direction * move_speed * climb_multiplier

	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

	var prepared_step_down_height := -1.0
	if enable_stair_stepping \
			and was_on_floor \
			and direction != Vector3.ZERO \
			and velocity.y <= 0.0:
		var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()
		var horizontal_motion := direction.normalized() * maxf(step_forward_distance, horizontal_speed * delta)
		prepared_step_down_height = _find_step_down_height(global_transform, horizontal_motion)
		if prepared_step_down_height > 0.0:
			velocity.y = minf(velocity.y, -prepared_step_down_height / maxf(delta, 0.001))

	var expected_horizontal_motion := Vector3(velocity.x, 0.0, velocity.z).length() * delta
	move_and_slide()
	if prepared_step_down_height > 0.0 and is_on_floor():
		_apply_stair_feedback(-prepared_step_down_height)

	var actual_horizontal_motion := Vector3(
		global_position.x - position_before_move.x,
		0.0,
		global_position.z - position_before_move.z).length()
	var movement_was_blocked := actual_horizontal_motion < expected_horizontal_motion * 0.55
	var stepped_up := false
	if enable_stair_stepping \
			and was_on_floor \
			and direction != Vector3.ZERO \
			and (_has_forward_wall_collision(direction) or movement_was_blocked):
		stepped_up = _try_step_up(direction, delta)
	if enable_stair_stepping \
			and not stepped_up \
			and direction != Vector3.ZERO \
			and velocity.y <= 0.0:
		_try_step_down()

	_update_viewmodel(delta, input_dir.length())


func _try_step_up(direction: Vector3, delta: float) -> bool:
	var original := global_transform
	var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var forward_distance := maxf(step_forward_distance, horizontal_speed * delta)
	var forward_motion := direction.normalized() * forward_distance
	var probe_lift := max_step_height + step_probe_clearance
	var up_motion := Vector3.UP * probe_lift

	if test_move(original, up_motion):
		_debug_stair("blocked while checking step height")
		return false

	var step_height := _find_step_height(original, forward_motion, probe_lift)
	if step_height < 0.0:
		_debug_stair("no usable step landing found")
		return false

	var stepped := original
	stepped.origin.y += step_height
	global_transform = stepped
	velocity.y = 0.0
	_apply_stair_feedback(step_height)
	_debug_stair("stepped up %.3f" % step_height)
	return true


func _try_step_down() -> bool:
	var original := global_transform
	var max_snap := minf(max_step_height, step_down_snap_height) + step_down_extra
	var down_collision := KinematicCollision3D.new()
	if not test_move(original, Vector3.DOWN * max_snap, down_collision):
		return false

	if down_collision.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
		return false

	var step_height := -down_collision.get_travel().y
	if step_height < min_step_height or step_height > max_snap + 0.01:
		return false

	global_transform = original.translated(down_collision.get_travel())
	velocity.y = 0.0
	apply_floor_snap()
	_apply_stair_feedback(-step_height)
	_debug_stair("stepped down %.3f" % step_height)
	return true


func _find_step_down_height(original: Transform3D, horizontal_motion: Vector3) -> float:
	if horizontal_motion.length_squared() <= 0.000001:
		return -1.0

	var probe := original.translated(horizontal_motion)
	var max_snap := minf(max_step_height, step_down_snap_height) + step_down_extra
	var down_collision := KinematicCollision3D.new()
	if not test_move(probe, Vector3.DOWN * max_snap, down_collision):
		return -1.0

	if down_collision.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
		return -1.0

	var step_height := -down_collision.get_travel().y
	if step_height < min_step_height or step_height > max_snap + 0.01:
		return -1.0

	return step_height


func _find_step_height(original: Transform3D, forward_motion: Vector3, probe_lift: float) -> float:
	var best_height := INF
	var raised := original.translated(Vector3.UP * probe_lift)
	var lowered_motion := Vector3.DOWN * (probe_lift + step_down_extra)

	for fraction: float in [0.35, 0.5, 0.7, 0.9, 1.0]:
		var sampled_forward: Vector3 = forward_motion * fraction
		if test_move(raised, sampled_forward):
			continue

		var down_collision := KinematicCollision3D.new()
		var forward_raised := raised.translated(sampled_forward)
		if not test_move(forward_raised, lowered_motion, down_collision):
			continue

		if down_collision.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
			continue

		var landed_probe := forward_raised.translated(down_collision.get_travel())
		var step_height := landed_probe.origin.y - original.origin.y
		if step_height >= min_step_height \
				and step_height <= max_step_height + 0.01 \
				and step_height < best_height:
			best_height = step_height

	return -1.0 if is_inf(best_height) else best_height


func _has_forward_wall_collision(direction: Vector3) -> bool:
	var forward := direction.normalized()
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var normal := collision.get_normal()
		if normal.dot(Vector3.UP) > 0.2:
			continue
		if forward.dot(-normal) > 0.35:
			return true
	return false


func _debug_stair(message: String) -> void:
	if debug_stair_stepping:
		print("[stair] ", message)


func _apply_stair_feedback(step_delta: float) -> void:
	var step_height := absf(step_delta)
	_stair_step_timer = stair_step_feedback_time
	_stair_step_strength = clampf(step_height / max_step_height, 0.0, 1.0)
	if step_delta > 0.0:
		_head_step_offset = minf(_head_step_offset, -step_height * 0.75)
	else:
		_head_step_offset = maxf(_head_step_offset, step_height * 0.75)


func _update_viewmodel(delta: float, input_amount: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	_water_hold_blend = move_toward(_water_hold_blend, _water_hold_target, water_hold_blend_speed * delta)
	_head_step_offset = move_toward(_head_step_offset, 0.0, stair_camera_step_smoothing * delta)
	head.position = _head_rest_position + Vector3.UP * _head_step_offset

	_look_sway = _look_sway.lerp(_look_sway_target, minf(1.0, look_sway_return_speed * delta))
	_look_sway_target = _look_sway_target.lerp(Vector2.ZERO, minf(1.0, look_sway_return_speed * delta))
	var stair_feedback := _stair_feedback(delta)

	# Walk bob/sway of the whole viewmodel.
	var bob := sin(t * 7.0) * walk_bob_amount * input_amount
	var sway := cos(t * 3.5) * walk_sway_amount * input_amount
	var look_offset := Vector3(
		clampf(-_look_sway.x * look_sway_position_amount, -0.035, 0.035),
		clampf(_look_sway.y * look_sway_position_amount, -0.025, 0.025),
		0.0)
	var stair_lift := Vector3(0.0, stair_feedback * stair_camera_lift_amount, 0.0)
	var target_position := viewmodel_rest_position + Vector3(sway, bob, 0.0) + look_offset + stair_lift
	viewmodel.position = viewmodel.position.lerp(target_position, minf(1.0, 8.0 * delta))

	if not _body:
		return

	# Idle breathing + gentle drift so the visible body does not feel locked in place.
	var breathe := sin(t * 1.3) * idle_breathe_amount
	var drift_x := sin(t * 0.6) * idle_drift_amount

	var g := 0.0
	var phase := fmod(t, 9.0)
	if phase < 1.5:
		g = sin(phase / 1.5 * PI)

	var water_position := water_hold_body_position_offset * _water_hold_blend
	var body_motion := Vector3(drift_x * 0.35, breathe * 0.45 + g * 0.012, 0.0) + water_position
	var body_rotation := wizard_body_rotation_degrees \
		+ Vector3(0.0, sin(t * 0.7) * 0.7, sin(t * 0.9) * 0.45)

	_update_body_visibility()
	_body.position = _body_rest_position + body_motion
	_body.rotation_degrees = body_rotation
	if _body_skeleton:
		_pose_wizard_hands()
	_update_body_materials()
	_update_first_person_model_arms()


func _update_body_materials() -> void:
	for material in _body_materials:
		material.set_shader_parameter("local_head_cut", body_local_head_cut)
		material.set_shader_parameter("local_arm_side_cut", body_local_arm_side_cut)
		material.set_shader_parameter("local_arm_height_cut", body_local_arm_height_cut)


func _update_body_visibility() -> void:
	if _body:
		_body.visible = head.rotation.x <= deg_to_rad(body_visible_pitch_degrees)


func _update_first_person_model_arms() -> void:
	if _left_viewmodel_arm == null or _right_viewmodel_arm == null:
		return

	var rotation := model_arm_rest_rotation_degrees.lerp(model_arm_water_rotation_degrees, _water_hold_blend)
	_left_viewmodel_arm.position = left_model_arm_rest_position.lerp(
		left_model_arm_water_position,
		_water_hold_blend)
	_right_viewmodel_arm.position = right_model_arm_rest_position.lerp(
		right_model_arm_water_position,
		_water_hold_blend)
	_left_viewmodel_arm.rotation_degrees = rotation
	_right_viewmodel_arm.rotation_degrees = rotation


func _on_held_changed(item: Node3D) -> void:
	_water_hold_target = 1.0 if _is_spring_water(item) else 0.0


func _is_spring_water(item: Node3D) -> bool:
	return item != null \
		and item.has_method("get_display_name") \
		and str(item.call("get_display_name")) == "Spring water"


func _stair_feedback(delta: float) -> float:
	if _stair_step_timer <= 0.0:
		_stair_step_strength = move_toward(_stair_step_strength, 0.0, delta * 6.0)
		return 0.0

	_stair_step_timer = maxf(0.0, _stair_step_timer - delta)
	var phase := 1.0 - _stair_step_timer / maxf(0.001, stair_step_feedback_time)
	return sin(phase * PI) * _stair_step_strength
