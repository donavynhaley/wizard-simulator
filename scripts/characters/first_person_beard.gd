@tool
class_name FirstPersonBeard
extends Node3D

const LIFT_ANIMATION := &"lift"
const LOWER_ANIMATION := &"lower"
const REST_ANIMATION := &"RESET"

@export_node_path("AnimationPlayer") var animation_player_path: NodePath = ^"BeardAnimationPlayer"
@export_node_path("Marker3D") var inventory_anchor_path: NodePath = ^"BeardRoot/BeardInventoryAnchor"

@onready var animation_player := get_node_or_null(animation_player_path) as AnimationPlayer
@onready var inventory_anchor := get_node_or_null(inventory_anchor_path) as Marker3D

var lifted := false


func _ready() -> void:
	if animation_player != null and not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)


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
