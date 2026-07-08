class_name ScribeArm
extends Node3D

## The wizard's right arm posed over the scribing table. Built from the shared
## wizard model, mesh-filtered down to the arm, and driven by TwoBoneIK3D so
## the hand follows the quill while drawing. The node origin is the shoulder:
## place and rotate this node to anchor the arm, then call track() each frame
## with the global position the hand should reach.

## Elbow hint in this node's local space (the IK pole). Slightly below and to
## the wizard's right of the shoulder gives a natural writing posture.
@export var elbow_hint := Vector3(0.0, -0.15, -0.25)
## Extra local rotation applied to the wrist so the palm drapes over the quill.
@export var wrist_rotation_degrees := Vector3(-50.0, -20.0, -10.0)
## Curl per finger phalanx, applied once at setup.
@export var finger_curl_degrees: float = -60.0
## Curl per thumb phalanx, applied once at setup.
@export var thumb_curl_degrees: float = -40.0

var _skeleton: Skeleton3D
var _ik: TwoBoneIK3D
var _target: Marker3D
var _pole: Marker3D
var _hand_attachment: BoneAttachment3D


func _ready() -> void:
	var model := WizardModel.instantiate()
	add_child(model)
	_skeleton = WizardModel.find_skeleton(model)
	if _skeleton == null:
		push_error("ScribeArm: wizard model has no skeleton.")
		return

	WizardModel.filter_to_bones(
		model,
		WizardModel.bone_indices(_skeleton, WizardModel.arm_bone_names(".R", true, false)))

	# Shift the model so the shoulder joint sits at this node's origin.
	# Global-space math so intermediate import nodes between the model root
	# and the skeleton cannot skew the offset.
	var arm_bone := _skeleton.find_bone("DEF-ARM.R")
	var shoulder_global: Vector3 = (
		_skeleton.global_transform * _skeleton.get_bone_global_rest(arm_bone)).origin
	model.global_position += global_position - shoulder_global

	_pose_grip()

	_target = Marker3D.new()
	_target.name = "HandTarget"
	add_child(_target)
	_pole = Marker3D.new()
	_pole.name = "ElbowPole"
	_pole.position = elbow_hint
	add_child(_pole)

	_hand_attachment = BoneAttachment3D.new()
	_hand_attachment.name = "HandAttachment"
	_skeleton.add_child(_hand_attachment)
	_hand_attachment.bone_name = "DEF-HAND.R"

	_ik = TwoBoneIK3D.new()
	_ik.name = "ArmIK"
	_skeleton.add_child(_ik)
	_ik.set_setting_count(1)
	_ik.set_root_bone_name(0, "DEF-ARM.R")
	_ik.set_middle_bone_name(0, "DEF-FOREARM.R")
	_ik.set_end_bone_name(0, "DEF-HAND.R")
	_ik.set_target_node(0, _ik.get_path_to(_target))
	_ik.set_pole_node(0, _ik.get_path_to(_pole))

	set_active(false)


## Shows the arm and enables IK solving (or the reverse). Keep the arm
## inactive outside scribing so the modifier does no per-frame work.
func set_active(active: bool) -> void:
	visible = active
	if _ik:
		_ik.active = active


## Moves the IK goal: the global position the hand bone should reach.
func track(hand_target_global: Vector3) -> void:
	if _target:
		_target.global_position = hand_target_global


## Where the hand bone actually ended up after the last solve (post-modifier
## pose via the BoneAttachment3D; the skeleton's script-visible poses exclude
## modifier output).
func hand_position() -> Vector3:
	if _hand_attachment:
		return _hand_attachment.global_position
	return global_position


func _pose_grip() -> void:
	_rotate_bone("DEF-HAND.R", wrist_rotation_degrees)
	for stem: String in ["DEF-FINGER01", "DEF-FINGER02", "DEF-FINGER03"]:
		_rotate_bone(stem + ".R", Vector3(finger_curl_degrees, 0.0, 0.0))
	for stem: String in ["DEF-THUMB01", "DEF-THUMB02", "DEF-THUMB03"]:
		_rotate_bone(stem + ".R", Vector3(thumb_curl_degrees, 0.0, 0.0))


func _rotate_bone(bone_name: String, degrees: Vector3) -> void:
	var bone := _skeleton.find_bone(bone_name)
	if bone == -1:
		return
	var curl := Quaternion.from_euler(Vector3(
		deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z)))
	_skeleton.set_bone_pose_rotation(bone, _skeleton.get_bone_pose_rotation(bone) * curl)
