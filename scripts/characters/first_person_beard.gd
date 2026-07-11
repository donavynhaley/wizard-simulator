@tool
class_name FirstPersonBeard
extends Node3D

const LIFT_ANIMATION := &"lift"
const LOWER_ANIMATION := &"lower"
const REST_ANIMATION := &"RESET"
const CONTROL_BONES := {
	"BeardRoot": ["DEF-SCARF01", "DEF-SCARF10"],
	"BeardRoot/Joint02": ["DEF-SCARF02", "DEF-SCARF09"],
	"BeardRoot/Joint02/Joint03": ["DEF-SCARF03", "DEF-SCARF08"],
	"BeardRoot/Joint02/Joint03/Joint04": [
		"DEF-SCARF04", "DEF-SCARF05", "DEF-SCARF06", "DEF-SCARF07"],
}

@export_node_path("AnimationPlayer") var animation_player_path: NodePath = ^"BeardAnimationPlayer"
@export_node_path("Marker3D") var inventory_anchor_path: NodePath = ^"BeardRoot/BeardInventoryAnchor"
@export_node_path("Node3D") var wizard_model_path: NodePath = ^"../../WizardModel"
@export_range(0.0, 1.0, 0.01) var model_pose_strength := 0.55
@export_range(0.0, 1.0, 0.01) var model_translation_strength := 0.5
@export var beard_control_rest_position := Vector3(0.0, 0.38, -0.1)

@onready var animation_player := get_node_or_null(animation_player_path) as AnimationPlayer
@onready var inventory_anchor := get_node_or_null(inventory_anchor_path) as Marker3D
@onready var wizard_model := get_node_or_null(wizard_model_path) as Node3D

var lifted := false
var _skeleton: Skeleton3D
var _base_rotations: Dictionary = {}
var _base_positions: Dictionary = {}
var _prepared := false


func _ready() -> void:
	if animation_player != null and not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	_prepare_model.call_deferred()
	set_process(true)


func _process(_delta: float) -> void:
	if not _prepared:
		_prepare_model()
	if _skeleton != null:
		_apply_model_pose()


func lift() -> void:
	lifted = true
	if animation_player != null:
		animation_player.play(LIFT_ANIMATION, 0.08)


func lower() -> void:
	lifted = false
	if animation_player != null:
		animation_player.play(LOWER_ANIMATION, 0.08)


func reset_pose() -> void:
	lifted = false
	if animation_player != null:
		animation_player.play(REST_ANIMATION)
		animation_player.advance(0.0)
		animation_player.stop()


func get_inventory_anchor() -> Marker3D:
	return inventory_anchor


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == LOWER_ANIMATION and not lifted:
		reset_pose()


func _prepare_model() -> void:
	if _prepared or wizard_model == null:
		return
	_skeleton = WizardModel.find_skeleton(wizard_model)
	if _skeleton == null:
		return
	for control_path in CONTROL_BONES:
		for bone_name in CONTROL_BONES[control_path]:
			var bone := _skeleton.find_bone(bone_name)
			if bone == -1:
				continue
			_base_rotations[bone_name] = _skeleton.get_bone_pose_rotation(bone)
			_base_positions[bone_name] = _skeleton.get_bone_pose_position(bone)
	_prepared = true


func _apply_model_pose() -> void:
	var beard_root := get_node_or_null(^"BeardRoot") as Node3D
	var translation_offset := Vector3.ZERO
	if beard_root != null:
		var body_offset := beard_root.position - beard_control_rest_position
		translation_offset = _skeleton.global_basis.inverse() \
			* (global_basis * body_offset) * model_translation_strength
	for control_path in CONTROL_BONES:
		var control := get_node_or_null(NodePath(control_path)) as Node3D
		if control == null:
			continue
		for bone_name in CONTROL_BONES[control_path]:
			var bone := _skeleton.find_bone(bone_name)
			if bone == -1 or not _base_rotations.has(bone_name):
				continue
			var offset_euler := control.rotation * model_pose_strength
			var strand_index := int(String(bone_name).trim_prefix("DEF-SCARF"))
			if strand_index >= 6:
				offset_euler.z *= -1.0
			var base_rotation := _base_rotations[bone_name] as Quaternion
			var rotation_offset := Quaternion.from_euler(offset_euler)
			_skeleton.set_bone_pose_rotation(
				bone,
				(base_rotation * rotation_offset).normalized())
			_skeleton.set_bone_pose_position(
				bone,
				(_base_positions[bone_name] as Vector3) + translation_offset)
