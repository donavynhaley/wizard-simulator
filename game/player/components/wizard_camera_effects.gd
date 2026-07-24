class_name WizardCameraEffects
extends Camera3D

@export var maximum_position_offset: Vector3 = Vector3(0.11, 0.09, 0.04)
@export_range(0.0, 10.0, 0.05) var maximum_roll_degrees: float = 2.5
@export_range(0.1, 10.0, 0.05) var trauma_decay: float = 1.8
@export_range(1.0, 100.0, 1.0) var noise_speed: float = 42.0

var _base_transform: Transform3D
var _noise: FastNoiseLite
var _noise_time: float = 0.0
var _trauma: float = 0.0


func _ready() -> void:
	_base_transform = transform
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.seed = randi()
	set_process(false)


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)
	if _trauma > 0.0:
		set_process(true)


func _process(delta: float) -> void:
	_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
	if _trauma <= 0.0:
		# Settle once and stop: a per-frame base write would stomp any other
		# writer of the camera transform (hand-flinch tweens, lean effects).
		transform = _base_transform
		set_process(false)
		return
	_noise_time += delta * noise_speed
	var strength := _trauma * _trauma
	var offset := Vector3(
		_noise.get_noise_2d(_noise_time, 0.0) * maximum_position_offset.x,
		_noise.get_noise_2d(0.0, _noise_time) * maximum_position_offset.y,
		_noise.get_noise_2d(_noise_time, _noise_time) * maximum_position_offset.z) * strength
	var roll := deg_to_rad(maximum_roll_degrees) * strength \
		* _noise.get_noise_2d(-_noise_time, _noise_time)
	transform = _base_transform
	position += offset
	rotation.z += roll
