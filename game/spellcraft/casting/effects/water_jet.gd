class_name WaterJet
extends Node3D

@export_range(0.1, 3.0, 0.05) var duration: float = 0.65
@export_range(1.0, 30.0, 0.5) var range: float = 12.0
@export_range(0.01, 1.0, 0.01) var pulse_interval: float = 0.1
@export_range(0.0, 100.0, 0.5) var impulse_per_pulse: float = 2.4

var element: Element
var caster: Node3D
var direction: Vector3 = Vector3.FORWARD
var _age: float = 0.0
var _pulse: float = 0.0

@onready var _stream: MeshInstance3D = $Stream


func configure(
		p_element: Element,
		p_caster: Node3D,
		_origin: Vector3,
		p_direction: Vector3) -> void:
	element = p_element
	caster = p_caster
	direction = p_direction.normalized()


func _ready() -> void:
	if element != null:
		var material := _stream.get_active_material(0) as StandardMaterial3D
		if material != null:
			material.albedo_color = Color(element.color, 0.62)
			material.emission = element.rim_color


func _physics_process(delta: float) -> void:
	_age += delta
	_pulse -= delta
	if _pulse <= 0.0:
		_pulse = pulse_interval
		_apply_pulse()
	var fade := 1.0 - clampf(_age / duration, 0.0, 1.0)
	scale = Vector3(1.0, 1.0, maxf(fade, 0.05))
	if _age >= duration:
		queue_free()


func _apply_pulse() -> void:
	var query := PhysicsRayQueryParameters3D.create(
		global_position, global_position + direction * range)
	query.collide_with_areas = false
	if caster is CollisionObject3D:
		query.exclude = [(caster as CollisionObject3D).get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var target := result.get("collider") as Node
	var impact := SpellImpact.new()
	impact.element = element
	impact.damage = 0.0
	impact.impulse = direction * impulse_per_pulse
	impact.position = result["position"] as Vector3
	impact.direction = direction
	impact.caster = caster
	impact.tags = [&"water", &"push", &"extinguish", &"wash"]
	SpellImpact.deliver(target, impact)
