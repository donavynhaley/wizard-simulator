class_name WizardHands
extends Node3D

## The wizard's hands. Holds one physical item in front of the camera. Left
## click casts a castable item, G drops whatever is held. Marked scene-unique
## (%HandAnchor); interactables reach it through the typed player.hands.

signal held_changed(item: Node3D)

@export_group("Held Item Pose")
@export var default_held_position: Vector3 = Vector3.ZERO
@export var default_held_rotation: Vector3 = Vector3(0.0, -0.35, 0.1)
@export var default_held_scale: Vector3 = Vector3.ONE

@export_group("Grab And Drop")
@export var pickup_time: float = 0.18
@export var drop_forward_impulse: float = 1.5
@export var drop_up_impulse: float = 0.5

@export_group("Visual Layers")
@export var held_item_visual_layer: int = 1 << 0
@export var world_item_visual_layer: int = 1 << 0

@export_group("Magical Grab Presentation")
@export_node_path("Node3D") var grab_presentation_path: NodePath = ^"MagicalGrabPresentation"

var held_item: Node3D
var _carry_tween: Tween
var _grab_presentation: MagicalGrabPresentation


func _ready() -> void:
	_grab_presentation = get_node_or_null(grab_presentation_path) as MagicalGrabPresentation


func pick_up(item: Node3D) -> void:
	if held_item and is_instance_valid(held_item):
		drop()
	_kill_carry_tween()
	held_item = item
	var item_parent := _grab_presentation.get_item_anchor() \
		if _grab_presentation != null else self
	item.reparent(item_parent)
	VisualLayers.apply_layer(item, held_item_visual_layer)
	if item.has_method("set_held"):
		item.set_held(true)
	var pose := _held_pose_for(item)
	item.scale = pose.scale
	_carry_tween = item.create_tween()
	_carry_tween.tween_property(item, "position", pose.position, pickup_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_carry_tween.parallel().tween_property(item, "rotation",
		pose.rotation, pickup_time)
	if _grab_presentation != null:
		_grab_presentation.show_grab(item)
	held_changed.emit(item)


func drop() -> void:
	_kill_carry_tween()
	if held_item == null or not is_instance_valid(held_item):
		held_item = null
		return
	var item := held_item
	held_item = null
	_hide_grab_presentation()
	item.reparent(get_tree().current_scene)
	VisualLayers.apply_layer(item, world_item_visual_layer)
	if item.has_method("set_held"):
		item.set_held(false)
	if item is RigidBody3D:
		if item.has_method("should_drop_straight_down") and bool(item.call("should_drop_straight_down")):
			(item as RigidBody3D).linear_velocity = Vector3.ZERO
			(item as RigidBody3D).angular_velocity = Vector3.ZERO
		else:
			var camera := get_viewport().get_camera_3d()
			var toss := -camera.global_transform.basis.z if camera else Vector3.FORWARD
			item.apply_central_impulse(toss * drop_forward_impulse + Vector3.UP * drop_up_impulse)
	held_changed.emit(null)


## Hand the item over to something else (a bench socket) without dropping it.
func release_item(item: Node3D) -> void:
	if held_item == item:
		_kill_carry_tween()
		held_item = null
		_hide_grab_presentation()
		VisualLayers.apply_layer(item, world_item_visual_layer)
		held_changed.emit(null)


func _kill_carry_tween() -> void:
	if _carry_tween and _carry_tween.is_valid():
		_carry_tween.kill()
	_carry_tween = null


func _held_pose_for(item: Node3D) -> Dictionary:
	if item.has_method("get_held_pose"):
		return item.call("get_held_pose")
	return {
		"position": default_held_position,
		"rotation": default_held_rotation,
		"scale": default_held_scale,
	}


## Called by items that cease to exist while held (a spent scroll crumbling).
func notify_item_gone(item: Node3D) -> void:
	if held_item == item:
		held_item = null
		_hide_grab_presentation()
		held_changed.emit(null)


func get_grab_presentation() -> MagicalGrabPresentation:
	return _grab_presentation


func _hide_grab_presentation() -> void:
	if _grab_presentation != null:
		_grab_presentation.hide_grab()


func _input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and held_item == null:
		return
	if event.is_action_pressed("drop_item") and held_item:
		drop()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cast"):
		if _try_cast():
			get_viewport().set_input_as_handled()


func _try_cast() -> bool:
	if held_item == null or not is_instance_valid(held_item):
		return false
	if not held_item.has_method("cast_from"):
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var status: String = str(held_item.call("cast_from", owner, camera.global_transform))
	if status != "":
		WizardHud.toast(self, status)
	return true
