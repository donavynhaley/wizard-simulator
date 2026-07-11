@tool
class_name FirstPersonWizardRig
extends Node3D

const GRAB_ANIMATION := &"grab"
const HOLD_ANIMATION := &"hold"
const RELEASE_ANIMATION := &"release"
const REST_ANIMATION := &"RESET"
const RIGHT_ARM_REST_POSITION := Vector3(0.2, -1.72, -0.86)
const RIGHT_ARM_HOLD_POSITION := Vector3(-0.09, -1.3, -1.08)
const LEFT_ARM_REST_POSITION := Vector3(-0.2, -1.72, -0.86)
const ARM_REST_ROTATION := Vector3(-0.488692, 3.141593, 0)
const LEFT_UPPER_ARM_BASE_ROTATION := Quaternion(
	-0.023753023, -0.006342602, -0.48897812, 0.87194955)
const LEFT_FOREARM_BASE_ROTATION := Quaternion(
	0.11957755, -0.34005535, -0.15658903, 0.9195344)
const RIGHT_UPPER_ARM_BASE_ROTATION := Quaternion(
	-0.023753023, 0.006342602, 0.48897812, 0.87194955)
const RIGHT_FOREARM_BASE_ROTATION := Quaternion(
	0.11957755, 0.34005535, 0.15658903, 0.9195344)
const CAMERA_INTERSECTION_BONES: Array[String] = ["DEF-HEAD", "DEF-NECK"]
const CONTROL_BONES := {
	"Wrist": "DEF-HAND.R",
	"Thumb01": "DEF-THUMB01.R",
	"Thumb02": "DEF-THUMB02.R",
	"Thumb03": "DEF-THUMB03.R",
	"Finger01": "DEF-FINGER01.R",
	"Finger02": "DEF-FINGER02.R",
	"Finger03": "DEF-FINGER03.R",
}

@export_node_path("Node3D") var arm_model_path: NodePath = ^"../../../../BodyRig/WizardModel"
@export_node_path("Node3D") var left_arm_pose_path: NodePath = ^"ArmModels/LeftArmPose"
@export_node_path("Node3D") var right_arm_pose_path: NodePath = ^"ArmModels/RightArmPose"
@export_node_path("Node3D") var hand_controls_path: NodePath = ^"HandControls"
@export_node_path("AnimationPlayer") var animation_player_path: NodePath = ^"GraspAnimationPlayer"
@export_node_path("AnimationPlayer") var beard_interaction_animation_player_path: NodePath = \
	^"BeardInteractionAnimationPlayer"
@export_node_path("Node3D") var beard_path: NodePath = ^"../../../../BodyRig/BeardAnchor/Beard"
@export_node_path("Node3D") var head_path: NodePath = ^"../../.."
@export_range(0.5, 1.5, 0.01) var arm_control_translation_scale := 1.0
@export_range(0.0, 1.0, 0.01) var arm_pitch_follow := 0.65
@export_range(-80.0, -5.0, 1.0) var beard_interaction_pitch_degrees := -22.0

@onready var arm_model := get_node_or_null(arm_model_path) as Node3D
@onready var left_arm_pose := get_node_or_null(left_arm_pose_path) as Node3D
@onready var right_arm_pose := get_node_or_null(right_arm_pose_path) as Node3D
@onready var hand_controls := get_node_or_null(hand_controls_path) as Node3D
@onready var animation_player := get_node_or_null(animation_player_path) as AnimationPlayer
@onready var beard_interaction_animation_player := \
	get_node_or_null(beard_interaction_animation_player_path) as AnimationPlayer
@onready var beard := get_node_or_null(beard_path) as FirstPersonBeard
@onready var head := get_node_or_null(head_path) as Node3D

var _skeleton: Skeleton3D
var _base_rotations: Dictionary = {}
var _base_positions: Dictionary = {}
var _prepared := false
var _holding_item := false


func _ready() -> void:
	_prepare_model.call_deferred()
	if animation_player != null and not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	set_process(true)
	set_process_unhandled_input(not Engine.is_editor_hint())


func _process(_delta: float) -> void:
	if not _prepared:
		_prepare_model()
	if _skeleton != null:
		_apply_arm_pose(left_arm_pose, "DEF-SHOULDER.L", LEFT_ARM_REST_POSITION)
		_apply_arm_pose(right_arm_pose, "DEF-SHOULDER.R", RIGHT_ARM_REST_POSITION)
		_apply_authored_arm_base_pose()
		_apply_hand_controls()
		_place_control_markers()


func set_holding_item(holding: bool) -> void:
	_holding_item = holding
	if animation_player == null:
		return
	if holding:
		animation_player.play(GRAB_ANIMATION, 0.08)
	else:
		animation_player.play(RELEASE_ANIMATION, 0.08)


func set_active(active: bool) -> void:
	set_process(active or Engine.is_editor_hint())
	set_process_unhandled_input(active and not Engine.is_editor_hint())
	if animation_player != null:
		animation_player.active = active or Engine.is_editor_hint()
	if beard_interaction_animation_player != null:
		beard_interaction_animation_player.active = active or Engine.is_editor_hint()


func get_grasp_animation_player() -> AnimationPlayer:
	return animation_player


func get_right_arm_pose() -> Node3D:
	return right_arm_pose


func get_left_arm_pose() -> Node3D:
	return left_arm_pose


func get_hand_control(control_name: StringName) -> Node3D:
	return hand_controls.get_node_or_null(NodePath(String(control_name))) as Node3D if hand_controls else null


func get_beard() -> FirstPersonBeard:
	return beard


func get_beard_interaction_animation_player() -> AnimationPlayer:
	return beard_interaction_animation_player


func get_arm_model_count() -> int:
	return 1 if arm_model != null else 0


func is_in_holding_pose() -> bool:
	return _holding_item and animation_player != null and animation_player.current_animation == HOLD_ANIMATION


func get_grasp_amount() -> float:
	if right_arm_pose == null:
		return 0.0
	var travel := RIGHT_ARM_REST_POSITION.distance_to(RIGHT_ARM_HOLD_POSITION)
	return clampf(RIGHT_ARM_REST_POSITION.distance_to(right_arm_pose.position) / travel, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if beard == null:
		return
	if event.is_action_pressed("check_beard_inventory"):
		if head == null or head.rotation.x > deg_to_rad(beard_interaction_pitch_degrees):
			return
		beard.lift()
		if beard_interaction_animation_player != null:
			beard_interaction_animation_player.play(&"lift", 0.08)
	elif event.is_action_released("check_beard_inventory"):
		beard.lower()
		if beard_interaction_animation_player != null:
			beard_interaction_animation_player.play(&"lower", 0.08)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == GRAB_ANIMATION and _holding_item:
		animation_player.play(HOLD_ANIMATION, 0.1)
	elif animation_name == RELEASE_ANIMATION and not _holding_item:
		animation_player.play(REST_ANIMATION)
		animation_player.advance(0.0)
		animation_player.stop()


func _prepare_model() -> void:
	if _prepared or arm_model == null:
		return
	_skeleton = WizardModel.find_skeleton(arm_model)
	if _skeleton == null:
		return
	if not arm_model.has_meta(&"first_person_body_filtered"):
		WizardModel.filter_to_bones(
			arm_model,
			WizardModel.bone_indices_except(_skeleton, CAMERA_INTERSECTION_BONES))
		arm_model.set_meta(&"first_person_body_filtered", true)
	_set_viewmodel_materials(arm_model)
	for control_name in CONTROL_BONES:
		_cache_bone(control_name, CONTROL_BONES[control_name])
	_cache_bone("LeftShoulder", "DEF-SHOULDER.L")
	_cache_bone("RightShoulder", "DEF-SHOULDER.R")
	_prepared = true


func _cache_bone(cache_name: String, bone_name: String) -> void:
	var bone := _skeleton.find_bone(bone_name)
	if bone == -1:
		return
	_base_rotations[cache_name] = _skeleton.get_bone_pose_rotation(bone)
	_base_positions[cache_name] = _skeleton.get_bone_pose_position(bone)


func _set_viewmodel_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_set_viewmodel_materials(child)


func _apply_arm_pose(control: Node3D, shoulder_name: String, rest_position: Vector3) -> void:
	if control == null:
		return
	var cache_name := "LeftShoulder" if shoulder_name.ends_with(".L") else "RightShoulder"
	var bone := _skeleton.find_bone(shoulder_name)
	if bone == -1 or not _base_rotations.has(cache_name):
		return
	var rig_position_offset := (control.position - rest_position) * arm_control_translation_scale
	var skeleton_position_offset := _skeleton.global_basis.inverse() \
		* (global_basis * rig_position_offset)
	var parent_bone := _skeleton.get_bone_parent(bone)
	var position_offset := skeleton_position_offset
	if parent_bone != -1:
		position_offset = _skeleton.get_bone_global_pose(parent_bone).basis.inverse() \
			* skeleton_position_offset
	var rotation_offset := Quaternion.from_euler(ARM_REST_ROTATION).inverse() \
		* Quaternion.from_euler(control.rotation)
	_skeleton.set_bone_pose_position(
		bone,
		(_base_positions[cache_name] as Vector3) + position_offset)
	_skeleton.set_bone_pose_rotation(
		bone,
		((_base_rotations[cache_name] as Quaternion) * rotation_offset).normalized())


func _apply_hand_controls() -> void:
	for control_name in CONTROL_BONES:
		var control := get_hand_control(control_name)
		var bone := _skeleton.find_bone(CONTROL_BONES[control_name])
		if control == null or bone == -1 or not _base_rotations.has(control_name):
			continue
		var base_rotation := _base_rotations[control_name] as Quaternion
		var offset := Quaternion.from_euler(control.rotation)
		_skeleton.set_bone_pose_rotation(bone, (base_rotation * offset).normalized())


func _apply_authored_arm_base_pose() -> void:
	var left_upper_arm := _skeleton.find_bone("DEF-ARM.L")
	var left_forearm := _skeleton.find_bone("DEF-FOREARM.L")
	var upper_arm := _skeleton.find_bone("DEF-ARM.R")
	var forearm := _skeleton.find_bone("DEF-FOREARM.R")
	var pitch := head.rotation.x * arm_pitch_follow if head != null else 0.0
	var pitch_offset := Quaternion(Vector3.RIGHT, pitch)
	if left_upper_arm != -1:
		_skeleton.set_bone_pose_rotation(
			left_upper_arm,
			(pitch_offset * LEFT_UPPER_ARM_BASE_ROTATION).normalized())
	if left_forearm != -1:
		_skeleton.set_bone_pose_rotation(
			left_forearm,
			(pitch_offset * LEFT_FOREARM_BASE_ROTATION).normalized())
	if upper_arm != -1:
		_skeleton.set_bone_pose_rotation(
			upper_arm,
			(pitch_offset * RIGHT_UPPER_ARM_BASE_ROTATION).normalized())
	if forearm != -1:
		_skeleton.set_bone_pose_rotation(
			forearm,
			(pitch_offset * RIGHT_FOREARM_BASE_ROTATION).normalized())


func _place_control_markers() -> void:
	for control_name in CONTROL_BONES:
		var control := get_hand_control(control_name)
		var bone := _skeleton.find_bone(CONTROL_BONES[control_name])
		if control == null or bone == -1:
			continue
		control.global_position = _skeleton.to_global(
			_skeleton.get_bone_global_pose(bone).origin)
