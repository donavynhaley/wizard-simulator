class_name WizardViewmodelMotion
extends Node

@export var rest_position: Vector3 = Vector3(0.0, -0.5, -0.55)
@export var walk_bob_amount: float = 0.012
@export var walk_sway_amount: float = 0.006
@export var look_sway_position_amount: float = 0.00045
@export var look_sway_return_speed: float = 9.0
@export var walk_gait_radians_per_meter: float = 1.67
@export var stair_camera_lift_amount: float = 0.045
@export var stair_camera_step_smoothing: float = 5.0
@export var stair_step_feedback_time: float = 0.32

var _head: Node3D
var _viewmodel: Node3D
var _head_rest_position: Vector3 = Vector3.ZERO
var _head_step_offset: float = 0.0
var _look_sway: Vector2 = Vector2.ZERO
var _look_sway_target: Vector2 = Vector2.ZERO
var _stair_step_timer: float = 0.0
var _stair_step_strength: float = 0.0
var _gait_phase: float = 0.0


func configure(head: Node3D, viewmodel: Node3D) -> void:
	_head = head
	_viewmodel = viewmodel
	_head_rest_position = head.position
	_viewmodel.position = rest_position


func add_look_sway(relative: Vector2) -> void:
	_look_sway_target = relative


func apply_stair_feedback(step_delta: float, max_step_height: float) -> void:
	var step_height := absf(step_delta)
	_stair_step_timer = stair_step_feedback_time
	_stair_step_strength = clampf(step_height / maxf(max_step_height, 0.001), 0.0, 1.0)
	if step_delta > 0.0:
		_head_step_offset = minf(_head_step_offset, -step_height * 0.75)
	else:
		_head_step_offset = maxf(_head_step_offset, step_height * 0.75)


func reset() -> void:
	_head_step_offset = 0.0
	_look_sway = Vector2.ZERO
	_look_sway_target = Vector2.ZERO
	_stair_step_timer = 0.0
	_stair_step_strength = 0.0
	if _head != null:
		_head.position = _head_rest_position
	if _viewmodel != null:
		_viewmodel.position = rest_position


func update(delta: float, horizontal_speed: float, move_speed: float) -> void:
	if _head == null or _viewmodel == null:
		return
	_head_step_offset = move_toward(
		_head_step_offset, 0.0, stair_camera_step_smoothing * delta)
	_head.position = _head_rest_position + Vector3.UP * _head_step_offset

	_look_sway = _look_sway.lerp(
		_look_sway_target, minf(1.0, look_sway_return_speed * delta))
	_look_sway_target = _look_sway_target.lerp(
		Vector2.ZERO, minf(1.0, look_sway_return_speed * delta))
	var stair_feedback := _stair_feedback(delta)

	if horizontal_speed > 0.01:
		_gait_phase = fmod(
			_gait_phase + horizontal_speed * delta * walk_gait_radians_per_meter,
			TAU * 2.0)
	var speed_ratio := clampf(horizontal_speed / maxf(move_speed, 0.001), 0.0, 1.0)
	var bob := sin(_gait_phase) * walk_bob_amount * speed_ratio
	var sway := cos(_gait_phase * 0.5) * walk_sway_amount * speed_ratio
	var look_offset := Vector3(
		clampf(-_look_sway.x * look_sway_position_amount, -0.035, 0.035),
		clampf(_look_sway.y * look_sway_position_amount, -0.025, 0.025),
		0.0)
	var stair_lift := Vector3(0.0, stair_feedback * stair_camera_lift_amount, 0.0)
	var target_position := rest_position + Vector3(sway, bob, 0.0) \
		+ look_offset + stair_lift
	_viewmodel.position = _viewmodel.position.lerp(
		target_position, minf(1.0, 8.0 * delta))


func _stair_feedback(delta: float) -> float:
	if _stair_step_timer <= 0.0:
		_stair_step_strength = move_toward(_stair_step_strength, 0.0, delta * 6.0)
		return 0.0

	_stair_step_timer = maxf(0.0, _stair_step_timer - delta)
	var phase := 1.0 - _stair_step_timer / maxf(0.001, stair_step_feedback_time)
	return sin(phase * PI) * _stair_step_strength
