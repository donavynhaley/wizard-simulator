class_name HeldFire
extends Node3D

@export var held_position: Vector3 = Vector3(-0.035, 0.025, -0.105)
@export var held_rotation: Vector3 = Vector3(-0.38, 0.18, -0.16)
@export var held_scale: Vector3 = Vector3.ONE


func get_held_pose() -> Dictionary:
	return {
		"position": held_position,
		"rotation": held_rotation,
		"scale": held_scale,
	}


func get_display_name() -> String:
	return "Eternal flame"


func set_held(value: bool) -> void:
	if not value:
		queue_free()


func consume() -> void:
	queue_free()
