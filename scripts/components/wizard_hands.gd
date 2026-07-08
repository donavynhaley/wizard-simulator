class_name WizardHands
extends Node3D

## The wizard's hands. Holds one physical item (a RuneStone or a SpellScroll)
## in front of the camera. Holding a scroll is the only way to cast it: left
## click casts, G drops whatever is held. Marked scene-unique (%HandAnchor) so
## props can find it from anywhere.

signal held_changed(item: Node3D)

@export_group("Held Item Pose")
@export var default_held_position: Vector3 = Vector3.ZERO
@export var default_held_rotation: Vector3 = Vector3(0.0, -0.35, 0.1)
@export var default_held_scale: Vector3 = Vector3.ONE

@export_group("Grab And Drop")
@export var pickup_time: float = 0.18
@export var grab_lift: float = 0.055
@export var drop_forward_impulse: float = 1.5
@export var drop_up_impulse: float = 0.5

@export_group("Visual Layers")
@export var held_item_visual_layer: int = 1 << 0
@export var world_item_visual_layer: int = 1 << 0

var held_item: Node3D
var _carry_tween: Tween
var _pose_tween: Tween
var _rest_position := Vector3.ZERO
var _rest_rotation := Vector3.ZERO


func _ready() -> void:
	_rest_position = position
	_rest_rotation = rotation


func pick_up(item: Node3D) -> void:
	if held_item and is_instance_valid(held_item):
		drop()
	_kill_carry_tween()
	held_item = item
	item.reparent(self)
	_set_visual_layer(item, held_item_visual_layer)
	if item.has_method("set_held"):
		item.set_held(true)
	var pose := _held_pose_for(item)
	item.scale = pose.scale
	_carry_tween = item.create_tween()
	_carry_tween.tween_property(item, "position", pose.position, pickup_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_carry_tween.parallel().tween_property(item, "rotation",
		pose.rotation, pickup_time)
	_play_grab_motion()
	held_changed.emit(item)


func drop() -> void:
	_kill_carry_tween()
	if held_item == null or not is_instance_valid(held_item):
		held_item = null
		return
	var item := held_item
	held_item = null
	item.reparent(get_tree().current_scene)
	_set_visual_layer(item, world_item_visual_layer)
	if item.has_method("set_held"):
		item.set_held(false)
	if item is RigidBody3D:
		var camera := get_viewport().get_camera_3d()
		var toss := -camera.global_transform.basis.z if camera else Vector3.FORWARD
		item.apply_central_impulse(toss * drop_forward_impulse + Vector3.UP * drop_up_impulse)
	held_changed.emit(null)


## Hand the item over to something else (a bench socket) without dropping it.
func release_item(item: Node3D) -> void:
	if held_item == item:
		_kill_carry_tween()
		held_item = null
		_set_visual_layer(item, world_item_visual_layer)
		held_changed.emit(null)


func _kill_carry_tween() -> void:
	if _carry_tween and _carry_tween.is_valid():
		_carry_tween.kill()
	_carry_tween = null
	if _pose_tween and _pose_tween.is_valid():
		_pose_tween.kill()
	_pose_tween = null


func _held_pose_for(item: Node3D) -> Dictionary:
	if item.has_method("get_held_pose"):
		return item.call("get_held_pose")
	return {
		"position": default_held_position,
		"rotation": default_held_rotation,
		"scale": default_held_scale,
	}


func _set_visual_layer(node: Node, layer_mask: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer_mask
	for child in node.get_children():
		_set_visual_layer(child, layer_mask)


func _play_grab_motion() -> void:
	if _pose_tween and _pose_tween.is_valid():
		_pose_tween.kill()
	position = _rest_position + Vector3(0.0, grab_lift, 0.0)
	_pose_tween = create_tween()
	_pose_tween.tween_property(self, "position", _rest_position, pickup_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose_tween.parallel().tween_property(self, "rotation", _rest_rotation, pickup_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Called by items that cease to exist while held (a spent scroll crumbling).
func notify_item_gone(item: Node3D) -> void:
	if held_item == item:
		held_item = null
		held_changed.emit(null)


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("drop_item") and held_item:
		drop()
	elif event.is_action_pressed("cast"):
		_try_cast()


func _try_cast() -> void:
	if held_item == null or not is_instance_valid(held_item):
		return
	if not held_item.has_method("cast_from"):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var status: String = str(held_item.call("cast_from", owner, camera.global_transform))
	var hud := get_tree().get_first_node_in_group("wizard_hud")
	if status != "" and hud and hud.has_method("show_toast"):
		hud.call("show_toast", status)
