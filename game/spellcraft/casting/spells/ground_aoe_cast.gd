class_name GroundAoeCast
extends SpellCast

## Ground-targeted AoE. While the spell is held, a reticle projects onto the
## ground where the player looks (clamped to max_range). Firing locks that point
## and detonates an expanding arcane burst there when the throw completes.

@export var reticle_scene: PackedScene
@export var explosion_scene: PackedScene
@export var max_range := 10.0
@export var explosion_radius := 2.5

var _reticle: Node3D
var _target := Vector3.ZERO
var _has_target := false
var _aiming := false


func _on_begin() -> void:
	_aiming = true
	if reticle_scene != null:
		# Parented to the behaviour so it is cleaned up with it; positioned each
		# frame in world space via global_transform.
		_reticle = reticle_scene.instantiate() as Node3D
		if _reticle != null:
			add_child(_reticle)
			_reticle.visible = false


func _physics_process(_delta: float) -> void:
	if _aiming:
		_update_target()


func _on_cast() -> void:
	# Lock the target and drop the reticle; the burst detonates on resolve().
	_aiming = false
	if _reticle != null:
		_reticle.queue_free()
		_reticle = null


func _on_resolve() -> void:
	if not _has_target or explosion_scene == null or _world == null:
		return
	var burst := explosion_scene.instantiate()
	_world.add_child(burst)
	if burst is Node3D:
		(burst as Node3D).global_position = _target
	burst.set(&"max_radius", explosion_radius)


func _update_target() -> void:
	if _camera == null:
		return
	var from := _camera.global_position
	var to := from + _look_dir().normalized() * max_range
	var space := _camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	if _caster is CollisionObject3D:
		query.exclude = [(_caster as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	_has_target = not hit.is_empty()
	if _reticle == null:
		return
	if _has_target:
		_target = hit["position"]
		var normal: Vector3 = hit["normal"]
		var basis := _aligned_basis(normal).scaled(Vector3.ONE * explosion_radius)
		_reticle.global_transform = Transform3D(basis, _target + normal * 0.02)
		_reticle.visible = true
	else:
		_reticle.visible = false


## Basis whose +Y aligns with the surface normal, so the flat torus ring lies on
## that surface.
func _aligned_basis(normal: Vector3) -> Basis:
	var up := normal.normalized()
	var fwd := Vector3.FORWARD
	if absf(up.dot(fwd)) > 0.99:
		fwd = Vector3.RIGHT
	var right := up.cross(fwd).normalized()
	fwd = right.cross(up).normalized()
	return Basis(right, up, fwd)
