class_name SpellProjectile
extends Area3D

## A straight-flying spell projectile. Moves at a fixed velocity and, on the first
## non-player body it touches (or when its life runs out), spawns an impact effect
## and despawns. The hit hook is where damage plugs in once there is a target.

signal hit(position: Vector3, collider: Node)

@export var lifetime := 3.0
@export var impact_scene: PackedScene

var _velocity := Vector3.ZERO
var _age := 0.0
var _spent := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(velocity: Vector3) -> void:
	_velocity = velocity
	if velocity.length() > 0.01:
		look_at(global_position + velocity, Vector3.UP)


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_age += delta
	if _age >= lifetime:
		_impact(global_position, null)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group(&"player"):
		return
	_impact(global_position, body)


func _impact(pos: Vector3, collider: Node) -> void:
	if _spent:
		return
	_spent = true
	hit.emit(pos, collider)
	var parent := get_parent()
	if impact_scene != null and parent != null:
		var burst := impact_scene.instantiate()
		parent.add_child(burst)
		if burst is Node3D:
			(burst as Node3D).global_position = pos
	queue_free()
