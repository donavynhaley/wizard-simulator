class_name WizardBodyRig
extends Node3D

## First-person presentation of the wizard's own body: mounts the full-body
## mesh (head and arm regions culled by shader so they never block the camera),
## builds the filtered viewmodel arms, and keeps everything posed against head
## pitch, idle motion, and the water-hold blend. Purely visual; movement and
## input live on WizardPlayer.

const LEFT_ARM_BASE_ROTATION := Quaternion(-0.023753023, -0.006342602, -0.48897812, 0.87194955)
const LEFT_FOREARM_BASE_ROTATION := Quaternion(0.07219099, -0.348859, -0.26778162, 0.89519763)
const RIGHT_ARM_BASE_ROTATION := Quaternion(-0.023753023, 0.006342602, 0.48897812, 0.87194955)
const RIGHT_FOREARM_BASE_ROTATION := Quaternion(0.07219099, 0.348859, 0.26778162, 0.89519763)
const ALL_3D_RENDER_LAYERS := (1 << 20) - 1
const WORLD_RENDER_LAYER := 1 << 0

@export_node_path("Node3D") var head_path: NodePath = ^"../Head"
@export_node_path("Camera3D") var camera_path: NodePath = ^"../Head/Camera3D"
@export_node_path("Node3D") var viewmodel_path: NodePath = ^"../Head/Camera3D/Viewmodel"

@export_group("Body Placement")
@export var body_position: Vector3 = Vector3(0.0, -0.84, 0.0)
@export var body_rotation_degrees: Vector3 = Vector3(0.0, 180.0, 0.0)
@export var body_scale: Vector3 = Vector3.ONE
@export var body_local_head_cut: float = 0.035
@export var body_local_arm_side_cut: float = 0.027
@export var body_local_arm_height_cut: float = 0.064
@export var body_visible_pitch_degrees: float = -35.0
@export var arm_pitch_follow: float = 0.45

@export_group("Idle Motion")
@export var idle_breathe_amount: float = 0.01
@export var idle_drift_amount: float = 0.006

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

@onready var _head: Node3D = get_node(head_path)
@onready var _camera: Camera3D = get_node(camera_path)
@onready var _viewmodel: Node3D = get_node(viewmodel_path)

var _body: Node3D
var _body_skeleton: Skeleton3D
var _body_materials: Array[ShaderMaterial] = []
var _viewmodel_arms_root: Node3D
var _left_viewmodel_arm: Node3D
var _right_viewmodel_arm: Node3D
var _water_hold_target := 0.0
var _water_hold_blend := 0.0


func _ready() -> void:
	_camera.cull_mask = ALL_3D_RENDER_LAYERS
	_mount_body()
	_mount_first_person_model_arms()
	var hands := get_node_or_null(^"%HandAnchor") as WizardHands
	if hands:
		hands.held_changed.connect(_on_held_changed)


## Pauses or resumes the idle body animation. WizardPlayer forwards its own
## control state here so the body freezes with the rest of the player.
func set_active(active: bool) -> void:
	set_process(active)


func _process(delta: float) -> void:
	_water_hold_blend = move_toward(_water_hold_blend, _water_hold_target, water_hold_blend_speed * delta)
	_update_body()
	_update_first_person_model_arms()


func _on_held_changed(item: Node3D) -> void:
	_water_hold_target = 1.0 if item is HeldWater else 0.0


func _mount_body() -> void:
	_body = WizardModel.instantiate()
	_body.name = "FirstPersonBody"
	_body.position = body_position
	_body.rotation_degrees = body_rotation_degrees
	_body.scale = body_scale
	add_child(_body)

	_body_skeleton = WizardModel.find_skeleton(_body)
	VisualLayers.apply_layer(_body, WORLD_RENDER_LAYER)
	if _body_skeleton:
		_pose_arms_to_head_pitch()
	_apply_body_material(_body)
	_refresh_cut_parameters()


func _update_body() -> void:
	if _body == null:
		return

	# Idle breathing + gentle drift so the visible body does not feel locked
	# in place, plus a periodic glance-like bob.
	var t := Time.get_ticks_msec() * 0.001
	var breathe := sin(t * 1.3) * idle_breathe_amount
	var drift_x := sin(t * 0.6) * idle_drift_amount
	var glance := 0.0
	var phase := fmod(t, 9.0)
	if phase < 1.5:
		glance = sin(phase / 1.5 * PI)

	var water_offset := water_hold_body_position_offset * _water_hold_blend
	_body.visible = _head.rotation.x <= deg_to_rad(body_visible_pitch_degrees)
	_body.position = body_position \
		+ Vector3(drift_x * 0.35, breathe * 0.45 + glance * 0.012, 0.0) \
		+ water_offset
	_body.rotation_degrees = body_rotation_degrees \
		+ Vector3(0.0, sin(t * 0.7) * 0.7, sin(t * 0.9) * 0.45)
	if _body_skeleton:
		_pose_arms_to_head_pitch()
	_refresh_cut_parameters()


func _pose_arms_to_head_pitch() -> void:
	if _body_skeleton == null:
		return
	var pitch_offset := Quaternion(Vector3.RIGHT, _head.rotation.x * arm_pitch_follow)
	_set_bone_rotation("DEF-ARM.L", (pitch_offset * LEFT_ARM_BASE_ROTATION).normalized())
	_set_bone_rotation("DEF-FOREARM.L", (pitch_offset * LEFT_FOREARM_BASE_ROTATION).normalized())
	_set_bone_rotation("DEF-ARM.R", (pitch_offset * RIGHT_ARM_BASE_ROTATION).normalized())
	_set_bone_rotation("DEF-FOREARM.R", (pitch_offset * RIGHT_FOREARM_BASE_ROTATION).normalized())


func _set_bone_rotation(bone_name: String, bone_rotation: Quaternion) -> void:
	var bone := _body_skeleton.find_bone(bone_name)
	if bone != -1:
		_body_skeleton.set_bone_pose_rotation(bone, bone_rotation)


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


func _refresh_cut_parameters() -> void:
	for material in _body_materials:
		material.set_shader_parameter("local_head_cut", body_local_head_cut)
		material.set_shader_parameter("local_arm_side_cut", body_local_arm_side_cut)
		material.set_shader_parameter("local_arm_height_cut", body_local_arm_height_cut)


func _mount_first_person_model_arms() -> void:
	if not show_first_person_model_arms:
		return

	_viewmodel_arms_root = Node3D.new()
	_viewmodel_arms_root.name = "FirstPersonModelArms"
	_viewmodel.add_child(_viewmodel_arms_root)

	_left_viewmodel_arm = _build_viewmodel_arm("LeftModelArm", false)
	_right_viewmodel_arm = _build_viewmodel_arm("RightModelArm", true)
	_update_first_person_model_arms()


func _build_viewmodel_arm(arm_name: String, mirrored: bool) -> Node3D:
	var arm := WizardModel.instantiate()
	arm.name = arm_name
	arm.scale = Vector3(-model_arm_scale, model_arm_scale, model_arm_scale) \
		if mirrored else Vector3.ONE * model_arm_scale
	_viewmodel_arms_root.add_child(arm)

	var skeleton := WizardModel.find_skeleton(arm)
	if skeleton:
		WizardModel.filter_to_bones(
			arm,
			WizardModel.bone_indices(skeleton, WizardModel.arm_bone_names(".L", false)))
		_set_viewmodel_materials(arm)
	return arm


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


func _update_first_person_model_arms() -> void:
	if _left_viewmodel_arm == null or _right_viewmodel_arm == null:
		return

	var arm_rotation := model_arm_rest_rotation_degrees.lerp(
		model_arm_water_rotation_degrees,
		_water_hold_blend)
	_left_viewmodel_arm.position = left_model_arm_rest_position.lerp(
		left_model_arm_water_position,
		_water_hold_blend)
	_right_viewmodel_arm.position = right_model_arm_rest_position.lerp(
		right_model_arm_water_position,
		_water_hold_blend)
	_left_viewmodel_arm.rotation_degrees = arm_rotation
	_right_viewmodel_arm.rotation_degrees = arm_rotation
