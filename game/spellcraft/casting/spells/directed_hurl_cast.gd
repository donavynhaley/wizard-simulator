class_name DirectedHurlCast
extends SpellCast

@export var expression_scene: PackedScene

var _direction: Vector3 = Vector3.FORWARD


func _on_cast() -> void:
	_direction = _look_dir().normalized()


func _on_resolve() -> void:
	if expression_scene == null or _world == null:
		return
	var expression := expression_scene.instantiate() as Node3D
	if expression == null:
		return
	if expression.has_method(&"configure"):
		expression.call(
			&"configure", element, _caster, _muzzle_position(), _direction)
	_world.add_child(expression)
	expression.global_position = _muzzle_position()
	if _direction.length_squared() > 0.001:
		expression.look_at(expression.global_position + _direction, Vector3.UP)
