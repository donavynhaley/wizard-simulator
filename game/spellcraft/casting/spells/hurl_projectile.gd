class_name HurlProjectile
extends Node3D

signal hit(position: Vector3, collider: Node)

@export_group("Flight")
@export_range(1.0, 100.0, 0.5) var maximum_range: float = 24.0
@export_range(0.0, 40.0, 0.1) var gravity: float = 0.0

@export_group("Impact")
@export var impact_scene: PackedScene
@export_range(0.0, 1000.0, 1.0) var damage: float = 0.0
@export_range(0.0, 100.0, 0.5) var impulse_strength: float = 0.0
@export var impact_tags: Array[StringName] = []

var element: Element
var caster: Node3D
var _velocity: Vector3 = Vector3.ZERO
var _distance_travelled: float = 0.0
var _spent: bool = false


func set_shader_param(parameter: StringName, value: Variant) -> void:
	var material := _orb_material()
	if material != null:
		material.set_shader_parameter(parameter, value)


func set_color(color: Color) -> void:
	set_shader_param(&"base_color", color)
	set_shader_param(&"rim_color", color.lightened(0.45))
	var light := get_node_or_null(^"Light") as OmniLight3D
	if light != null:
		light.light_color = color


func launch(velocity: Vector3) -> void:
	_velocity = velocity
	if velocity.length() > 0.01:
		look_at(global_position + velocity, Vector3.UP)


func _physics_process(delta: float) -> void:
	if _spent or _velocity.length_squared() <= 0.0001:
		return
	_velocity.y -= gravity * delta
	var step := _velocity * delta
	var remaining := maximum_range - _distance_travelled
	if step.length() > remaining:
		step = step.normalized() * maxf(remaining, 0.0)
	var next_position := global_position + step
	var collision := _sweep(global_position, next_position)
	if not collision.is_empty():
		global_position = collision["position"] as Vector3
		_impact(global_position, collision["collider"] as Node)
		return
	global_position = next_position
	_distance_travelled += step.length()
	if _distance_travelled >= maximum_range - 0.001:
		_impact(global_position, null)
	elif _velocity.length() > 0.01:
		look_at(global_position + _velocity, Vector3.UP)


func _sweep(from: Vector3, to: Vector3) -> Dictionary:
	if from.is_equal_approx(to):
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	if caster is CollisionObject3D:
		query.exclude = [(caster as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _impact(position: Vector3, collider: Node) -> void:
	if _spent:
		return
	_spent = true
	hit.emit(position, collider)
	if impact_scene != null:
		_spawn_impact_scene(position)
	elif collider != null:
		var impact := SpellImpact.new()
		impact.element = element
		impact.damage = damage
		impact.position = position
		impact.direction = _velocity.normalized()
		impact.impulse = impact.direction * impulse_strength
		impact.caster = caster
		impact.tags = impact_tags.duplicate()
		SpellImpact.deliver(collider, impact)
	queue_free()


func _spawn_impact_scene(position: Vector3) -> void:
	var effect := impact_scene.instantiate() as Node3D
	if effect == null:
		return
	if effect.has_method(&"configure"):
		effect.call(&"configure", element, caster)
	var world: Node = get_tree().current_scene
	if world == null:
		world = get_tree().root
	world.add_child(effect)
	effect.global_position = position


func _orb_material() -> ShaderMaterial:
	var orb := get_node_or_null(^"Orb") as MeshInstance3D
	if orb == null:
		return null
	return orb.get_active_material(0) as ShaderMaterial
