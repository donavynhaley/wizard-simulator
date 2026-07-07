class_name WizardHands
extends Node3D

## The wizard's hands. Holds one physical item (a RuneStone or a SpellScroll)
## in front of the camera. Holding a scroll is the only way to cast it: left
## click casts, G drops whatever is held. Marked scene-unique (%HandAnchor) so
## props can find it from anywhere.

signal held_changed(item: Node3D)

var held_item: Node3D
var _carry_tween: Tween


func pick_up(item: Node3D) -> void:
	if held_item and is_instance_valid(held_item):
		drop()
	_kill_carry_tween()
	held_item = item
	if item.has_method("set_held"):
		item.set_held(true)
	item.reparent(self)
	item.scale = Vector3.ONE
	_carry_tween = item.create_tween()
	_carry_tween.tween_property(item, "position", Vector3.ZERO, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_carry_tween.parallel().tween_property(item, "rotation",
		Vector3(0.0, -0.35, 0.1), 0.18)
	held_changed.emit(item)


func drop() -> void:
	_kill_carry_tween()
	if held_item == null or not is_instance_valid(held_item):
		held_item = null
		return
	var item := held_item
	held_item = null
	item.reparent(get_tree().current_scene)
	if item.has_method("set_held"):
		item.set_held(false)
	if item is RigidBody3D:
		var camera := get_viewport().get_camera_3d()
		var toss := -camera.global_transform.basis.z if camera else Vector3.FORWARD
		item.apply_central_impulse(toss * 1.5 + Vector3.UP * 0.5)
	held_changed.emit(null)


## Hand the item over to something else (a bench socket) without dropping it.
func release_item(item: Node3D) -> void:
	if held_item == item:
		_kill_carry_tween()
		held_item = null
		held_changed.emit(null)


func _kill_carry_tween() -> void:
	if _carry_tween and _carry_tween.is_valid():
		_carry_tween.kill()
	_carry_tween = null


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
	var journal := SpellbookJournal.find(get_tree())
	if status != "" and journal:
		journal.announce(status)
