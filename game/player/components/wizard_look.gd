class_name WizardLook
extends Node

@export var mouse_sensitivity: float = 0.0022
@export_range(45.0, 80.0, 1.0) var pitch_limit_degrees: float = 75.0


func apply(body: Node3D, head: Node3D, relative: Vector2) -> void:
	body.rotate_y(-relative.x * mouse_sensitivity)
	head.rotate_x(-relative.y * mouse_sensitivity)
	var pitch_limit := deg_to_rad(pitch_limit_degrees)
	head.rotation.x = clampf(head.rotation.x, -pitch_limit, pitch_limit)
