class_name ViewmodelMotion
extends Node

## Procedural life for the worn viewmodel (the wizard hat). The authored editor
## transform is captured as the rest pose; each visual frame this layers small
## offsets on top so the hat reads as a physical object resting on the head
## instead of a mesh bolted to the camera. Everything composes in the camera's
## local frame and stays subtle - the goal is "felt, not seen".
##
## CastingController-style wiring: WizardPlayer calls configure() once with the
## body, head, and the node to animate, then this drives itself in _process.

@export_group("Look Sway")
## View rotation speed (rad/sec) below which the hat does not react at all.
## Normal aiming/looking stays under this, so only fast whips register - this
## is what keeps the brim still during ordinary play instead of always moving.
@export var sway_deadzone := 4.0
## Radians of trailing offset per rad/sec of view rotation past the deadzone.
@export var sway_angular_gain := 0.022
## Hard cap on trailing offset so a fast flick can't swing the hat off-screen.
@export var sway_max := 0.05
## How fast the hat catches back up to the view; higher = tighter/less laggy.
@export var sway_stiffness := 20.0
## Bank (roll) per rad/sec of yaw past the deadzone, leaning into fast turns.
@export var bank_gain := 0.01
@export var bank_max := 0.03

@export_group("Head Bob")
@export var bob_enabled := true
## Stride phase advance per metre travelled; pairs with horizontal speed.
@export var bob_frequency := 1.75
@export var bob_amplitude_y := 0.0035
@export var bob_amplitude_x := 0.0022
## Slight roll rocked in sync with the stride.
@export var bob_roll := 0.007
## Seconds-ish for the bob to fade in/out as you start/stop moving.
@export var bob_blend_speed := 6.0

@export_group("Idle Breathing")
@export var breath_frequency := 1.1
@export var breath_amplitude := 0.002

@export_group("Look-Up Compensation")
## Above this pitch (looking up) the brim starts easing out of view.
@export var brim_pitch_reference_deg := 55.0
## Metres the hat lifts at full look-up so the brim clears the view.
@export var brim_lift := 0.022
## Radians the brim tucks back at full look-up.
@export var brim_tuck := 0.10

var _body: CharacterBody3D
var _head: Node3D
var _target: Node3D

var _rest: Transform3D
var _configured := false

var _sway := Vector3.ZERO          ## smoothed pitch/yaw/roll trailing offset
var _bob_phase := 0.0
var _bob_weight := 0.0
var _breath_time := 0.0
var _prev_yaw := 0.0
var _prev_pitch := 0.0


## Wired once from WizardPlayer._ready. body drives speed/on-floor, head owns
## pitch, target is the node whose authored transform we animate (the hat).
func configure(body: CharacterBody3D, head: Node3D, target: Node3D) -> void:
	_body = body
	_head = head
	_target = target
	if _target != null:
		_rest = _target.transform
	if _body != null:
		_prev_yaw = _body.rotation.y
	if _head != null:
		_prev_pitch = _head.rotation.x
	_configured = _body != null and _head != null and _target != null


func _process(delta: float) -> void:
	if not _configured or delta <= 0.0:
		return

	_update_look_sway(delta)
	_update_bob(delta)
	_breath_time += delta

	var pitch := _sway.x
	var yaw := _sway.y
	var roll := _sway.z
	var offset := Vector3.ZERO

	# Head bob: figure-eight, vertical at double the stride frequency.
	if _bob_weight > 0.001:
		offset.y += sin(_bob_phase * 2.0) * bob_amplitude_y * _bob_weight
		offset.x += sin(_bob_phase) * bob_amplitude_x * _bob_weight
		roll += sin(_bob_phase) * bob_roll * _bob_weight

	# Idle breathing fills in whenever the bob is faded out.
	offset.y += sin(_breath_time * breath_frequency * TAU) * breath_amplitude \
			* (1.0 - _bob_weight)

	# Look-up compensation keeps the brim off the centre of the screen.
	var look_up := clampf(_head.rotation.x / deg_to_rad(brim_pitch_reference_deg),
			0.0, 1.0)
	offset.y += look_up * brim_lift
	pitch += look_up * brim_tuck

	var offset_basis := Basis.from_euler(Vector3(pitch, yaw, roll))
	_target.transform = Transform3D(offset_basis, offset) * _rest


## Drives the trailing offset from view angular velocity. The target is the
## velocity-scaled lag; when the view stops moving the target is zero and the
## hat eases home, so a single smoothing step gives both trail and recenter.
func _update_look_sway(delta: float) -> void:
	var yaw := _body.rotation.y
	var pitch := _head.rotation.x
	# Soft-knee deadzone: subtract the threshold so slow, deliberate looking
	# yields exactly zero and only the speed *past* the whip threshold drives
	# the hat - it ramps in from nothing rather than popping on at the edge.
	var yaw_vel := _deadzone(wrapf(yaw - _prev_yaw, -PI, PI) / delta, sway_deadzone)
	var pitch_vel := _deadzone((pitch - _prev_pitch) / delta, sway_deadzone)
	_prev_yaw = yaw
	_prev_pitch = pitch

	var target := Vector3(
		clampf(-pitch_vel * sway_angular_gain, -sway_max, sway_max),
		clampf(-yaw_vel * sway_angular_gain, -sway_max, sway_max),
		clampf(yaw_vel * bank_gain, -bank_max, bank_max))
	_sway = _sway.lerp(target, 1.0 - exp(-sway_stiffness * delta))


## Signed amount of v beyond +/- dz; zero inside the deadzone.
static func _deadzone(v: float, dz: float) -> float:
	return signf(v) * maxf(absf(v) - dz, 0.0)


func _update_bob(delta: float) -> void:
	var speed := 0.0
	var moving := false
	if bob_enabled and _body.is_on_floor():
		speed = Vector2(_body.velocity.x, _body.velocity.z).length()
		moving = speed > 0.35
	var target_weight := 1.0 if moving else 0.0
	_bob_weight = move_toward(_bob_weight, target_weight, bob_blend_speed * delta)
	if moving:
		_bob_phase += speed * bob_frequency * delta
