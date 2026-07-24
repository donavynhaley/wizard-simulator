class_name SpellImpact
extends RefCounted

var element: Element
var damage: float = 0.0
var impulse: Vector3 = Vector3.ZERO
var position: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.ZERO
var caster: Node3D
var tags: Array[StringName] = []


static func deliver(target: Node, impact: SpellImpact) -> void:
	if target == null or impact == null:
		return
	if target.has_method(&"receive_spell_impact"):
		target.call(&"receive_spell_impact", impact)
		return
	if target is RigidBody3D:
		(target as RigidBody3D).apply_central_impulse(impact.impulse)
	elif target is CharacterBody3D:
		(target as CharacterBody3D).velocity += impact.impulse
