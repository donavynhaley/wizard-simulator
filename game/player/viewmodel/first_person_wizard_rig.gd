@tool
class_name FirstPersonWizardRig
extends Node3D

const GRAB_ANIMATION := &"grab"
const HOLD_ANIMATION := &"hold"
const RELEASE_ANIMATION := &"release"
const IDLE_ANIMATION := &"idle"
const RIGHT_ARM_REST_POSITION := Vector3(0.2, -1.72, -0.86)
const RIGHT_ARM_IDLE_POSITION := Vector3(0.2, -1.735, -0.86)
const RIGHT_ARM_HOLD_POSITION := Vector3(0.2, -1.76, -0.86)
const LEFT_ARM_REST_POSITION := Vector3(-0.2, -1.72, -0.86)
const ARM_REST_ROTATION := Vector3(-0.488692, 3.141593, 0)
const RIGHT_ARM_IDLE_ROTATION := Vector3(-0.488692, 3.141593, 0.1)
const RIGHT_ARM_HOLD_ROTATION := Vector3(-0.5, 3.141593, 0.68)
const LEFT_UPPER_ARM_BASE_ROTATION := Quaternion(
	-0.023753023, -0.006342602, -0.48897812, 0.87194955)
const LEFT_FOREARM_BASE_ROTATION := Quaternion(
	0.11957755, -0.34005535, -0.15658903, 0.9195344)
const RIGHT_UPPER_ARM_BASE_ROTATION := Quaternion(
	-0.023753023, 0.006342602, 0.48897812, 0.87194955)
const RIGHT_FOREARM_BASE_ROTATION := Quaternion(
	0.11957755, 0.34005535, 0.15658903, 0.9195344)
const CAMERA_INTERSECTION_BONES: Array[String] = [
	"DEF-HEAD",
	"DEF-NECK",
	"DEF-FOREARM-HANG01.L",
	"DEF-FOREARM-HANG02.L",
	"DEF-FOREARM-HANG03.L",
	"DEF-FOREARM-HANG01.R",
	"DEF-FOREARM-HANG02.R",
	"DEF-FOREARM-HANG03.R",
]
const CONTROL_BONES := {
	"Wrist": "DEF-HAND.R",
	"Thumb01": "DEF-THUMB01.R",
	"Thumb02": "DEF-THUMB02.R",
	"Thumb03": "DEF-THUMB03.R",
	"Finger01": "DEF-FINGER01.R",
	"Finger02": "DEF-FINGER02.R",
	"Finger03": "DEF-FINGER03.R",
}
const ARM_IK_CHAINS := [
	{
		"root": "DEF-ARM.L",
		"middle": "DEF-FOREARM.L",
		"end": "DEF-HAND.L",
	},
	{
		"root": "DEF-ARM.R",
		"middle": "DEF-FOREARM.R",
		"end": "DEF-HAND.R",
	},
]

@export_node_path("Node3D") var arm_model_path: NodePath = ^"../../../../BodyRig/WizardModel"
@export_node_path("Node3D") var left_arm_pose_path: NodePath = ^"ArmModels/LeftArmPose"
@export_node_path("Node3D") var right_arm_pose_path: NodePath = ^"ArmModels/RightArmPose"
@export_node_path("Node3D") var hand_controls_path: NodePath = ^"HandControls"
@export_node_path("AnimationPlayer") var animation_player_path: NodePath = ^"GraspAnimationPlayer"
@export_node_path("AnimationPlayer") var beard_interaction_animation_player_path: NodePath = \
	^"BeardInteractionAnimationPlayer"
@export_node_path("Node3D") var beard_path: NodePath = ^"../../../../BodyRig/BeardAnchor/Beard"
@export_node_path("Node3D") var head_path: NodePath = ^"../../.."
@export_node_path("Camera3D") var camera_path: NodePath = ^"../.."
@export_node_path("Node3D") var left_hand_target_path: NodePath = \
	^"../CameraLocalArmTargets/LeftHandTarget"
@export_node_path("Node3D") var left_elbow_pole_path: NodePath = \
	^"../CameraLocalArmTargets/LeftElbowPole"
@export_node_path("Node3D") var right_hand_target_path: NodePath = \
	^"../CameraLocalArmTargets/RightHandTarget"
@export_node_path("Node3D") var right_elbow_pole_path: NodePath = \
	^"../CameraLocalArmTargets/RightElbowPole"
@export_range(0.5, 1.5, 0.01) var arm_control_translation_scale := 1.0
@export_range(0.5, 1.0, 0.01) var camera_hand_horizontal_scale := 0.62
@export_range(-0.2, 0.0, 0.01) var camera_hand_vertical_offset := -0.08
@export_range(0.0, 60.0, 1.0) var hat_screen_lock_start_pitch_degrees := 12.0
@export_range(0.0, 1.5, 0.01) var hat_screen_lock_strength := 1.0
@export_range(-80.0, -5.0, 1.0) var beard_interaction_pitch_degrees := -22.0
@export var preview_control_rig_in_editor := false

@onready var arm_model := get_node_or_null(arm_model_path) as Node3D
@onready var left_arm_pose := get_node_or_null(left_arm_pose_path) as Node3D
@onready var right_arm_pose := get_node_or_null(right_arm_pose_path) as Node3D
@onready var hand_controls := get_node_or_null(hand_controls_path) as Node3D
@onready var animation_player := get_node_or_null(animation_player_path) as AnimationPlayer
@onready var beard_interaction_animation_player := \
	get_node_or_null(beard_interaction_animation_player_path) as AnimationPlayer
@onready var beard := get_node_or_null(beard_path) as FirstPersonBeard
@onready var head := get_node_or_null(head_path) as Node3D
@onready var camera := get_node_or_null(camera_path) as Camera3D
@onready var left_hand_target := get_node_or_null(left_hand_target_path) as Node3D
@onready var left_elbow_pole := get_node_or_null(left_elbow_pole_path) as Node3D
@onready var right_hand_target := get_node_or_null(right_hand_target_path) as Node3D
@onready var right_elbow_pole := get_node_or_null(right_elbow_pole_path) as Node3D

var _skeleton: Skeleton3D
var _base_rotations: Dictionary = {}
var _base_positions: Dictionary = {}
var _arm_ik_chains: Array[Dictionary] = []
var _camera_local_hand_ik: TwoBoneIK3D
var _camera_local_hand_orientation: CopyTransformModifier3D
var _prepared := false
var _holding_item := false
var _active := true
var _reading_book: Book


func _ready() -> void:
	_prepare_model.call_deferred()
	if animation_player != null and not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
		animation_player.play(IDLE_ANIMATION)
	set_process(true)
	set_process_unhandled_input(not Engine.is_editor_hint())


func _process(_delta: float) -> void:
	if not _prepared:
		_prepare_model()
	_update_camera_local_hand_modifiers_active()
	if Engine.is_editor_hint() and not preview_control_rig_in_editor:
		return
	if _skeleton != null:
		_apply_arm_pose(left_arm_pose, "DEF-SHOULDER.L", LEFT_ARM_REST_POSITION)
		_apply_arm_pose(right_arm_pose, "DEF-SHOULDER.R", RIGHT_ARM_REST_POSITION)
		_apply_authored_arm_base_pose()
		_apply_hat_screen_lock()
		_apply_hand_controls()
		_update_camera_local_arm_targets()


func set_holding_item(holding: bool) -> void:
	if holding == _holding_item:
		if not holding and animation_player != null \
				and animation_player.current_animation != IDLE_ANIMATION:
			animation_player.play(IDLE_ANIMATION, 0.1)
		return
	_holding_item = holding
	if animation_player == null:
		return
	if holding:
		animation_player.play(GRAB_ANIMATION, 0.08)
	else:
		animation_player.play(RELEASE_ANIMATION, 0.08)


func set_reading_book(book: Book) -> void:
	_reading_book = book


func get_reading_book() -> Book:
	return _reading_book if is_instance_valid(_reading_book) else null


func set_active(active: bool) -> void:
	_active = active
	set_process(active or Engine.is_editor_hint())
	set_process_unhandled_input(active and not Engine.is_editor_hint())
	if animation_player != null:
		animation_player.active = active or Engine.is_editor_hint()
	if beard_interaction_animation_player != null:
		beard_interaction_animation_player.active = active or Engine.is_editor_hint()
	_update_camera_local_hand_modifiers_active()


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
	var position_travel := RIGHT_ARM_IDLE_POSITION.distance_to(RIGHT_ARM_HOLD_POSITION)
	var position_amount := RIGHT_ARM_IDLE_POSITION.distance_to(right_arm_pose.position) \
		/ maxf(position_travel, 0.001)
	var rest_rotation := Quaternion.from_euler(RIGHT_ARM_IDLE_ROTATION)
	var hold_rotation := Quaternion.from_euler(RIGHT_ARM_HOLD_ROTATION)
	var rotation_travel := rest_rotation.angle_to(hold_rotation)
	var rotation_amount := rest_rotation.angle_to(Quaternion.from_euler(right_arm_pose.rotation)) \
		/ maxf(rotation_travel, 0.001)
	return clampf(maxf(position_amount, rotation_amount), 0.0, 1.0)


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
		animation_player.play(IDLE_ANIMATION, 0.1)


func _prepare_model() -> void:
	if _prepared or arm_model == null:
		return
	_skeleton = WizardModel.find_skeleton(arm_model)
	if _skeleton == null:
		return
	if not Engine.is_editor_hint():
		WizardModel.filter_to_bones(
			arm_model,
			WizardModel.bone_indices_except(_skeleton, CAMERA_INTERSECTION_BONES))
	_set_viewmodel_materials(arm_model)
	for control_name in CONTROL_BONES:
		_cache_bone(control_name, CONTROL_BONES[control_name])
	_cache_bone("LeftShoulder", "DEF-SHOULDER.L")
	_cache_bone("RightShoulder", "DEF-SHOULDER.R")
	_cache_bone("ModelHead", "DEF-HEAD")
	_prepare_camera_local_hand_modifiers()
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
		* (_get_neutral_viewmodel_basis() * rig_position_offset)
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
	if left_upper_arm != -1:
		_skeleton.set_bone_pose_rotation(
			left_upper_arm,
			LEFT_UPPER_ARM_BASE_ROTATION)
	if left_forearm != -1:
		_skeleton.set_bone_pose_rotation(
			left_forearm,
			LEFT_FOREARM_BASE_ROTATION)
	if upper_arm != -1:
		_skeleton.set_bone_pose_rotation(
			upper_arm,
			RIGHT_UPPER_ARM_BASE_ROTATION)
	if forearm != -1:
		_skeleton.set_bone_pose_rotation(
			forearm,
			RIGHT_FOREARM_BASE_ROTATION)


## The skeleton lives inside an imported scene, so its runtime modifiers are
## composed here after the imported bone hierarchy is available.
func _prepare_camera_local_hand_modifiers() -> void:
	if _skeleton == null or camera == null:
		return
	var targets: Array[Node3D] = [left_hand_target, right_hand_target]
	var poles: Array[Node3D] = [left_elbow_pole, right_elbow_pole]
	if targets.any(func(target: Node3D) -> bool: return target == null) \
			or poles.any(func(pole: Node3D) -> bool: return pole == null):
		return
	_camera_local_hand_ik = _skeleton.get_node_or_null("CameraLocalHandIK") as TwoBoneIK3D
	if _camera_local_hand_ik == null:
		_camera_local_hand_ik = TwoBoneIK3D.new()
		_camera_local_hand_ik.name = "CameraLocalHandIK"
		_skeleton.add_child(_camera_local_hand_ik)
	_camera_local_hand_orientation = _skeleton.get_node_or_null(
		"CameraLocalHandOrientation") as CopyTransformModifier3D
	if _camera_local_hand_orientation == null:
		_camera_local_hand_orientation = CopyTransformModifier3D.new()
		_camera_local_hand_orientation.name = "CameraLocalHandOrientation"
		_skeleton.add_child(_camera_local_hand_orientation)
	_skeleton.move_child(
		_camera_local_hand_orientation,
		min(_camera_local_hand_ik.get_index() + 1, _skeleton.get_child_count() - 1))
	_camera_local_hand_ik.setting_count = ARM_IK_CHAINS.size()
	_camera_local_hand_orientation.setting_count = ARM_IK_CHAINS.size()
	_arm_ik_chains.clear()
	for index in ARM_IK_CHAINS.size():
		var bone_names := ARM_IK_CHAINS[index] as Dictionary
		var root_bone := _skeleton.find_bone(bone_names["root"] as String)
		var middle_bone := _skeleton.find_bone(bone_names["middle"] as String)
		var end_bone := _skeleton.find_bone(bone_names["end"] as String)
		if root_bone == -1 or middle_bone == -1 or end_bone == -1:
			continue
		_arm_ik_chains.append({
			"middle": middle_bone,
			"end": end_bone,
			"target": targets[index],
			"pole": poles[index],
		})
		_camera_local_hand_ik.set_root_bone(index, root_bone)
		_camera_local_hand_ik.set_middle_bone(index, middle_bone)
		_camera_local_hand_ik.set_end_bone(index, end_bone)
		_camera_local_hand_ik.set_target_node(
			index, _camera_local_hand_ik.get_path_to(targets[index]))
		_camera_local_hand_ik.set_pole_node(
			index, _camera_local_hand_ik.get_path_to(poles[index]))
		_camera_local_hand_orientation.set_apply_bone(index, end_bone)
		_camera_local_hand_orientation.set_reference_type(
			index, BoneConstraint3D.REFERENCE_TYPE_NODE)
		_camera_local_hand_orientation.set_reference_node(
			index, _camera_local_hand_orientation.get_path_to(targets[index]))
		_camera_local_hand_orientation.set_copy_flags(
			index, CopyTransformModifier3D.TRANSFORM_FLAG_ROTATION)
		_camera_local_hand_orientation.set_relative(index, false)
		_camera_local_hand_orientation.set_additive(index, false)
	if not _camera_local_hand_orientation.modification_processed.is_connected(
			_on_camera_local_hand_modifiers_processed):
		_camera_local_hand_orientation.modification_processed.connect(
			_on_camera_local_hand_modifiers_processed)
	_update_camera_local_hand_modifiers_active()


## Reads the authored body-space pose as if the camera were level, then moves
## its complete wrist and elbow targets into the camera's current frame.
func _update_camera_local_arm_targets() -> void:
	if _camera_local_hand_ik == null or not _camera_local_hand_ik.active or camera == null:
		return
	if _update_book_reading_arm_targets():
		return
	var neutral_camera_transform := _get_neutral_camera_transform()
	for chain in _arm_ik_chains:
		var middle_world := _bone_world_position(chain["middle"] as int)
		var hand_world_transform := _bone_world_transform(chain["end"] as int)
		var hand_world := hand_world_transform.origin
		var camera_local_hand := neutral_camera_transform.affine_inverse() * hand_world
		camera_local_hand.x *= camera_hand_horizontal_scale
		camera_local_hand.y += camera_hand_vertical_offset
		var target := chain["target"] as Node3D
		var pole := chain["pole"] as Node3D
		target.global_position = camera.global_transform * camera_local_hand
		var camera_local_hand_basis := (
			neutral_camera_transform.basis.inverse() * hand_world_transform.basis
		).orthonormalized()
		target.global_basis = (
			camera.global_basis.orthonormalized() * camera_local_hand_basis
		).orthonormalized()
		var camera_local_elbow := neutral_camera_transform.affine_inverse() * middle_world
		camera_local_elbow.x *= camera_hand_horizontal_scale
		camera_local_elbow.y += camera_hand_vertical_offset
		pole.global_position = camera.global_transform * camera_local_elbow


func _update_book_reading_arm_targets() -> bool:
	if _reading_book == null or not is_instance_valid(_reading_book):
		_reading_book = null
		return false
	var grips := _reading_book.get_reading_hand_grips()
	if grips.size() != 2 or _arm_ik_chains.size() < 2:
		return false
	for index in 2:
		var chain := _arm_ik_chains[index]
		var target := chain["target"] as Node3D
		var pole := chain["pole"] as Node3D
		target.global_transform = grips[index]
		var side := -1.0 if index == 0 else 1.0
		pole.global_position = target.global_position \
			+ camera.global_basis * Vector3(side * 0.2, -0.16, 0.1)
	return true


func _get_neutral_camera_transform() -> Transform3D:
	if head == null or camera == null or not head.get_parent() is Node3D:
		return camera.global_transform if camera != null else global_transform
	var body := head.get_parent() as Node3D
	var head_basis := body.global_basis.orthonormalized()
	var basis := (head_basis * camera.transform.basis).orthonormalized()
	var origin := head.global_position + head_basis * camera.position
	return Transform3D(basis, origin)


func _get_neutral_viewmodel_basis() -> Basis:
	var neutral_camera_basis := _get_neutral_camera_transform().basis
	var viewmodel_basis: Basis = get_parent().transform.basis \
		if get_parent() is Node3D else Basis.IDENTITY
	return (neutral_camera_basis * viewmodel_basis * transform.basis).orthonormalized()


func _bone_world_position(bone: int) -> Vector3:
	return _skeleton.to_global(_skeleton.get_bone_global_pose(bone).origin)


func _bone_world_transform(bone: int) -> Transform3D:
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)


func _update_camera_local_hand_modifiers_active() -> void:
	if _camera_local_hand_ik == null:
		return
	var modifiers_active := _active \
		and (not Engine.is_editor_hint() or preview_control_rig_in_editor)
	_camera_local_hand_ik.active = modifiers_active
	if _camera_local_hand_orientation != null:
		_camera_local_hand_orientation.active = modifiers_active


func _on_camera_local_hand_modifiers_processed() -> void:
	_place_control_markers()


func _apply_hat_screen_lock() -> void:
	var head_bone := _skeleton.find_bone("DEF-HEAD")
	if head_bone == -1 or not _base_rotations.has("ModelHead"):
		return
	var upward_pitch := maxf(head.rotation.x, 0.0) if head != null else 0.0
	var lock_start := deg_to_rad(hat_screen_lock_start_pitch_degrees)
	var locked_pitch := -maxf(upward_pitch - lock_start, 0.0) * hat_screen_lock_strength
	var pitch_offset := Quaternion(Vector3.RIGHT, locked_pitch)
	var base_rotation := _base_rotations["ModelHead"] as Quaternion
	_skeleton.set_bone_pose_rotation(
		head_bone,
		(pitch_offset * base_rotation).normalized())


func _place_control_markers() -> void:
	for control_name in CONTROL_BONES:
		var control := get_hand_control(control_name)
		var bone := _skeleton.find_bone(CONTROL_BONES[control_name])
		if control == null or bone == -1:
			continue
		control.global_position = _skeleton.to_global(
			_skeleton.get_bone_global_pose(bone).origin)
