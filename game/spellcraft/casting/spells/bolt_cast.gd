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
	# A wavering hand costs punch before it costs function: the bolt still
	# flies - slower, softer, wobbling as the verb fights its own shape.
	var stability := clampf(quality, 0.0, 1.0)
	proj.set(&"stability", stability)
	var authored_damage: Variant = proj.get(&"damage")
	if authored_damage != null:
		proj.set(&"damage", float(authored_damage) * lerpf(0.65, 1.0, stability))
	_world.add_child(proj)
	if proj is Node3D:
		(proj as Node3D).global_position = _muzzle_position()
	if element != null:
		element.apply_to(proj)
	if proj.has_method("launch"):
		proj.call("launch", _fire_dir * speed * lerpf(0.8, 1.0, stability))
