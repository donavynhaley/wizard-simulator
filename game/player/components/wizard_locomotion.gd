class_name WizardLocomotion
extends Node

@export_group("Movement")
@export var move_speed: float = 4.2
@export var acceleration: float = 16.0
@export var deceleration: float = 12.0
@export var air_acceleration: float = 5.0
@export var air_deceleration: float = 1.0

@export_group("Jumping")
@export var jump_velocity: float = 4.5
@export_range(0.0, 0.3, 0.01) var coyote_time: float = 0.12
@export_range(0.0, 0.3, 0.01) var jump_buffer_time: float = 0.12
@export_range(0.1, 1.0, 0.05) var jump_release_velocity_multiplier: float = 0.45

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0


func reset(body: CharacterBody3D) -> void:
	body.velocity = Vector3.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0


func physics_step(body: CharacterBody3D, input_direction: Vector2, delta: float) -> void:
	var was_on_floor := body.is_on_floor()
	var world_input := body.transform.basis * Vector3(
		input_direction.x, 0.0, input_direction.y)
	world_input.y = 0.0
	_update_jump_windows(delta, was_on_floor)
	var jumped := _try_buffered_jump(body)

	if not was_on_floor and not jumped:
		body.velocity.y -= _gravity * delta

	if Input.is_action_just_released(&"jump") and body.velocity.y > 0.0:
		body.velocity.y *= jump_release_velocity_multiplier

	var target_velocity := Vector2(world_input.x, world_input.z) \
		* move_speed
	var horizontal_velocity := Vector2(body.velocity.x, body.velocity.z)
	var control_rate := acceleration if was_on_floor else air_acceleration
	if input_direction.is_zero_approx():
		control_rate = deceleration if was_on_floor else air_deceleration
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, control_rate * delta)
	body.velocity.x = horizontal_velocity.x
	body.velocity.z = horizontal_velocity.y

	body.move_and_slide()
	if not jumped and body.is_on_floor():
		_try_buffered_jump(body)


func _update_jump_windows(delta: float, was_on_floor: bool) -> void:
	if was_on_floor:
		_coyote_timer = maxf(coyote_time, delta)
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_timer = maxf(jump_buffer_time, delta)
	else:
		_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)


func _try_buffered_jump(body: CharacterBody3D) -> bool:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return false
	body.velocity.y = jump_velocity
	if not Input.is_action_pressed(&"jump"):
		body.velocity.y *= jump_release_velocity_multiplier
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	return true
