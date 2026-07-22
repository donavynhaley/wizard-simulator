class_name BoltCast
extends SpellCast

## Magic bolt: a straight-line projectile fired from the hand along the look
## direction, locked in at the click and launched when the throw completes.

@export var projectile_scene: PackedScene
@export var speed := 24.0

var _fire_dir := Vector3.FORWARD


func _on_cast() -> void:
	# Lock the direction at the click; the projectile launches on resolve().
	_fire_dir = _look_dir().normalized()


func _on_resolve() -> void:
	if projectile_scene == null or _world == null:
		return
	var proj := projectile_scene.instantiate()
	proj.set(&"element", element)
	proj.set(&"caster", _caster)
	_world.add_child(proj)
	if proj is Node3D:
		(proj as Node3D).global_position = _muzzle_position()
	if element != null:
		element.apply_to(proj)
	if proj.has_method("launch"):
		proj.call("launch", _fire_dir * speed)
