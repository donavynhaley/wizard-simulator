class_name AirGust
extends Node3D

@export_range(1.0, 30.0, 0.5) var range: float = 9.0
@export_range(5.0, 89.0, 1.0) var half_angle_degrees: float = 36.0
@export_range(0.0, 100.0, 0.5) var impulse_strength: float = 15.0
@export_range(0.1, 3.0, 0.05) var lifetime: float = 0.8

var element: Element
var caster: Node3D
var direction: Vector3 = Vector3.FORWARD
var _applied: bool = false


func configure(
		p_element: Element,
		p_caster: Node3D,
		_origin: Vector3,
		p_direction: Vector3) -> void:
	element = p_element
	caster = p_caster
	direction = p_direction.normalized()


func _ready() -> void:
	var cleanup := create_tween()
	cleanup.tween_interval(lifetime)
	cleanup.tween_callback(queue_free)


func _physics_process(_delta: float) -> void:
	if _applied:
		return
	_applied = true
	var sphere := SphereShape3D.new()
	sphere.radius = range
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collide_with_areas = false
	var results := get_world_3d().direct_space_state.intersect_shape(query, 128)
	var minimum_dot := cos(deg_to_rad(half_angle_degrees))
	var affected: Dictionary[int, bool] = {}
	for result: Dictionary in results:
		var target := result.get("collider") as Node3D
		if target == null or target == caster or affected.has(target.get_instance_id()):
			continue
		var offset := target.global_position - global_position
		var distance := offset.length()
		if distance <= 0.05 or direction.dot(offset.normalized()) < minimum_dot:
			continue
		affected[target.get_instance_id()] = true
		var falloff := 1.0 - clampf(distance / range, 0.0, 1.0)
		var impact := SpellImpact.new()
		impact.element = element
		impact.impulse = direction * impulse_strength * lerpf(0.25, 1.0, falloff)
		impact.position = target.global_position
		impact.direction = direction
		impact.caster = caster
		impact.tags = [&"air", &"gust", &"disrupt", &"deflect"]
		SpellImpact.deliver(target, impact)
