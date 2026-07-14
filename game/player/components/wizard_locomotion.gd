class_name WizardLocomotion
extends Node

signal stair_stepped(step_delta: float, configured_max_step_height: float)

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

@export_group("Stair Stepping")
@export var enable_stair_stepping: bool = true
@export var max_step_height: float = 0.5
@export var min_step_height: float = 0.08
@export var step_probe_clearance: float = 0.35
@export var step_forward_distance: float = 0.5
@export var step_down_extra: float = 0.08
@export var step_down_snap_height: float = 0.5
@export var stair_floor_snap_length: float = 0.45
@export_range(0.1, 1.0, 0.01) var stair_climb_speed_multiplier: float = 0.72
@export var stair_step_feedback_time: float = 0.32
@export var debug_stair_stepping: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _stair_step_timer: float = 0.0


func configure(body: CharacterBody3D) -> void:
	body.floor_snap_length = maxf(body.floor_snap_length, stair_floor_snap_length)


func reset(body: CharacterBody3D) -> void:
	body.velocity = Vector3.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_stair_step_timer = 0.0


func physics_step(body: CharacterBody3D, input_direction: Vector2, delta: float) -> float:
	var was_on_floor := body.is_on_floor()
	var position_before_move := body.global_position
	var world_input := body.transform.basis * Vector3(
		input_direction.x, 0.0, input_direction.y)
	world_input.y = 0.0
	var direction := world_input.normalized() \
		if not world_input.is_zero_approx() else Vector3.ZERO
	var pre_snapped_down := false
	_update_jump_windows(delta, was_on_floor)
	var jumped := _try_buffered_jump(body)

	if enable_stair_stepping \
			and not was_on_floor \
			and direction != Vector3.ZERO \
			and body.velocity.y <= 0.0 \
			and not jumped:
		pre_snapped_down = _try_step_down(body)

	if not body.is_on_floor() and not pre_snapped_down and not jumped:
		body.velocity.y -= _gravity * delta

	if Input.is_action_just_released(&"jump") and body.velocity.y > 0.0:
		body.velocity.y *= jump_release_velocity_multiplier

	var climb_multiplier := stair_climb_speed_multiplier \
		if _stair_step_timer > 0.0 else 1.0
	var target_velocity := Vector2(world_input.x, world_input.z) \
		* move_speed * climb_multiplier
	var horizontal_velocity := Vector2(body.velocity.x, body.velocity.z)
	var grounded_control := was_on_floor or body.is_on_floor()
	var control_rate := acceleration if grounded_control else air_acceleration
	if input_direction.is_zero_approx():
		control_rate = deceleration if grounded_control else air_deceleration
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, control_rate * delta)
	body.velocity.x = horizontal_velocity.x
	body.velocity.z = horizontal_velocity.y

	var prepared_step_down_height := -1.0
	if enable_stair_stepping \
			and was_on_floor \
			and direction != Vector3.ZERO \
			and body.velocity.y <= 0.0:
		var horizontal_speed := Vector3(
			body.velocity.x, 0.0, body.velocity.z).length()
		var horizontal_motion := direction.normalized() \
			* maxf(step_forward_distance, horizontal_speed * delta)
		prepared_step_down_height = _find_step_down_height(
			body, body.global_transform, horizontal_motion)
		if prepared_step_down_height > 0.0:
			body.velocity.y = minf(
				body.velocity.y, -prepared_step_down_height / maxf(delta, 0.001))

	var expected_horizontal_motion := Vector3(
		body.velocity.x, 0.0, body.velocity.z).length() * delta
	body.move_and_slide()
	if not jumped and body.is_on_floor():
		_try_buffered_jump(body)
	if prepared_step_down_height > 0.0 and body.is_on_floor():
		_apply_stair_feedback(-prepared_step_down_height)

	var actual_horizontal_motion := Vector3(
		body.global_position.x - position_before_move.x,
		0.0,
		body.global_position.z - position_before_move.z).length()
	var movement_was_blocked := actual_horizontal_motion < expected_horizontal_motion * 0.55
	var stepped_up := false
	if enable_stair_stepping \
			and was_on_floor \
			and direction != Vector3.ZERO \
			and (_has_forward_wall_collision(body, direction) or movement_was_blocked):
		stepped_up = _try_step_up(body, direction, delta)
	if enable_stair_stepping \
			and not stepped_up \
			and direction != Vector3.ZERO \
			and body.velocity.y <= 0.0:
		_try_step_down(body)

	_stair_step_timer = maxf(0.0, _stair_step_timer - delta)
	return actual_horizontal_motion / maxf(delta, 0.001) if body.is_on_floor() else 0.0


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


func _try_step_up(body: CharacterBody3D, direction: Vector3, delta: float) -> bool:
	var original := body.global_transform
	var horizontal_speed := Vector3(body.velocity.x, 0.0, body.velocity.z).length()
	var forward_distance := maxf(step_forward_distance, horizontal_speed * delta)
	var forward_motion := direction.normalized() * forward_distance
	var probe_lift := max_step_height + step_probe_clearance
	var up_motion := Vector3.UP * probe_lift

	if body.test_move(original, up_motion):
		_debug_stair("blocked while checking step height")
		return false

	var step_height := _find_step_height(body, original, forward_motion, probe_lift)
	if step_height < 0.0:
		_debug_stair("no usable step landing found")
		return false

	var stepped := original
	stepped.origin.y += step_height
	body.global_transform = stepped
	body.velocity.y = 0.0
	_apply_stair_feedback(step_height)
	_debug_stair("stepped up %.3f" % step_height)
	return true


func _try_step_down(body: CharacterBody3D) -> bool:
	var original := body.global_transform
	var max_snap := minf(max_step_height, step_down_snap_height) + step_down_extra
	var down_collision := KinematicCollision3D.new()
	if not body.test_move(original, Vector3.DOWN * max_snap, down_collision):
		return false

	if down_collision.get_normal().dot(Vector3.UP) < cos(body.floor_max_angle):
		return false

	var step_height := -down_collision.get_travel().y
	if step_height < min_step_height or step_height > max_snap + 0.01:
		return false

	body.global_transform = original.translated(down_collision.get_travel())
	body.velocity.y = 0.0
	body.apply_floor_snap()
	_apply_stair_feedback(-step_height)
	_debug_stair("stepped down %.3f" % step_height)
	return true


func _find_step_down_height(
		body: CharacterBody3D,
		original: Transform3D,
		horizontal_motion: Vector3) -> float:
	if horizontal_motion.length_squared() <= 0.000001:
		return -1.0

	var probe := original.translated(horizontal_motion)
	var max_snap := minf(max_step_height, step_down_snap_height) + step_down_extra
	var down_collision := KinematicCollision3D.new()
	if not body.test_move(probe, Vector3.DOWN * max_snap, down_collision):
		return -1.0

	if down_collision.get_normal().dot(Vector3.UP) < cos(body.floor_max_angle):
		return -1.0

	var step_height := -down_collision.get_travel().y
	if step_height < min_step_height or step_height > max_snap + 0.01:
		return -1.0

	return step_height


func _find_step_height(
		body: CharacterBody3D,
		original: Transform3D,
		forward_motion: Vector3,
		probe_lift: float) -> float:
	var best_height := INF
	var raised := original.translated(Vector3.UP * probe_lift)
	var lowered_motion := Vector3.DOWN * (probe_lift + step_down_extra)

	for fraction: float in [0.35, 0.5, 0.7, 0.9, 1.0]:
		var sampled_forward: Vector3 = forward_motion * fraction
		if body.test_move(raised, sampled_forward):
			continue

		var down_collision := KinematicCollision3D.new()
		var forward_raised := raised.translated(sampled_forward)
		if not body.test_move(forward_raised, lowered_motion, down_collision):
			continue

		if down_collision.get_normal().dot(Vector3.UP) < cos(body.floor_max_angle):
			continue

		var landed_probe := forward_raised.translated(down_collision.get_travel())
		var step_height := landed_probe.origin.y - original.origin.y
		if step_height >= min_step_height \
				and step_height <= max_step_height + 0.01 \
				and step_height < best_height:
			best_height = step_height

	return -1.0 if is_inf(best_height) else best_height


func _has_forward_wall_collision(body: CharacterBody3D, direction: Vector3) -> bool:
	var forward := direction.normalized()
	for index in body.get_slide_collision_count():
		var collision := body.get_slide_collision(index)
		var normal := collision.get_normal()
		if normal.dot(Vector3.UP) > 0.2:
			continue
		if forward.dot(-normal) > 0.35:
			return true
	return false


func _apply_stair_feedback(step_delta: float) -> void:
	_stair_step_timer = stair_step_feedback_time
	stair_stepped.emit(step_delta, max_step_height)


func _debug_stair(message: String) -> void:
	if debug_stair_stepping:
		print("[stair] ", message)
