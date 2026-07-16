class_name SpellProjectile
extends Area3D

## A straight-flying spell projectile. Moves at a fixed velocity and, on the first
## non-player body it touches (or when its life runs out), spawns an impact effect
## and despawns. The hit hook is where damage plugs in once there is a target.

signal hit(position: Vector3, collider: Node)

@export var lifetime := 3.0
@export var impact_scene: PackedScene

var element: Element   ## carried through so the impact burst matches the bolt
var _velocity := Vector3.ZERO
var _age := 0.0
var _spent := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func set_shader_param(param: StringName, value: Variant) -> void:
	var mat := _orb_material()
	if mat != null:
		mat.set_shader_parameter(param, value)


func set_color(c: Color) -> void:
	set_shader_param(&"base_color", c)
	set_shader_param(&"rim_color", c.lightened(0.45))
	var light := get_node_or_null(^"Light") as OmniLight3D
	if light != null:
		light.light_color = c


func _orb_material() -> ShaderMaterial:
	var orb := get_node_or_null(^"Orb") as MeshInstance3D
	if orb == null:
		return null
	return orb.get_active_material(0) as ShaderMaterial


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
		if element != null:
			element.apply_to(burst)
	queue_free()
