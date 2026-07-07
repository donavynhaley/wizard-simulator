extends CharacterBody3D

@export var move_speed: float = 4.2
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.0022
@export var acceleration: float = 16.0
@export var deceleration: float = 12.0

# CC-BY low-poly first-person arms by Player11132 (via poly.pizza). See CREDITS.md.
const ARMS_SCENE := preload("res://assets/external/polypizza/fps_arms.glb")

@onready var head: Node3D = $Head
@onready var viewmodel: Node3D = $Head/Camera3D/Viewmodel

# Raw mesh centroid (native units) so the arms can be recentered on their pivot.
const ARMS_CENTROID := Vector3(2.68, 0.0, 4.54)
const ARMS_SCALE := 0.07
const PIVOT_BASE_POS := Vector3(0.0, -0.02, -0.12)
const PIVOT_BASE_ROT := Vector3(-16.0, 0.0, 0.0)

## Temporary diagnostics for the Wayland mouse-capture hunt; flip off once solved.
const LOOK_DEBUG := true

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _arms: Node3D
var _arms_pivot: Node3D
var _viewmodel_base_y: float = 0.0
var _want_capture := true
var _motion_count := 0
var _last_attempt_log := -10.0
var _heartbeat := 0.0


func _ready() -> void:
	_log("ready: display_server=%s embedded=%s cmdline=%s" % [
		DisplayServer.get_name(),
		str("--embedded" in OS.get_cmdline_args()),
		str(OS.get_cmdline_args())])
	_log("ready: window mode=%d focused=%s mouse_mode=%d" % [
		get_window().mode, str(get_window().has_focus()), Input.mouse_mode])
	_try_capture("ready")
	_viewmodel_base_y = viewmodel.position.y
	_mount_arms()


## Godot's Wayland backend can only capture while the cursor is over the game
## window ("pointed_win is null" otherwise), so a single request at startup can
## silently fail (e.g. focusing the window from the keyboard on Hyprland).
## Keep wanting capture and re-apply whenever it can actually succeed.
func _try_capture(reason: String) -> void:
	if not _want_capture or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var ok := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	# Motion-triggered retries can fire every frame; only log a state change
	# or one failure per half second.
	var now := Time.get_ticks_msec() / 1000.0
	if ok or now - _last_attempt_log > 0.5:
		_last_attempt_log = now
		_log("capture attempt (%s): %s (mouse_mode=%d)" % [
			reason, "SUCCESS" if ok else "failed", Input.mouse_mode])


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_MOUSE_ENTER:
			_log("WM_MOUSE_ENTER")
			_try_capture("mouse_enter")
		NOTIFICATION_WM_MOUSE_EXIT:
			_log("WM_MOUSE_EXIT")
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_log("WM_WINDOW_FOCUS_IN")
			_try_capture("window_focus_in")
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_log("WM_WINDOW_FOCUS_OUT")
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_log("APPLICATION_FOCUS_IN")
			_try_capture("app_focus_in")
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_log("APPLICATION_FOCUS_OUT")


func _log(msg: String) -> void:
	if LOOK_DEBUG:
		print("[mouselook %7.2fs] %s" % [Time.get_ticks_msec() / 1000.0, msg])


func _mount_arms() -> void:
	# A pivot re-centers the off-origin mesh so idle sway rotates cleanly. The mesh's
	# hands are at its native -Z end, so no yaw flip is needed to point them forward.
	_arms_pivot = Node3D.new()
	_arms_pivot.name = "ArmsPivot"
	_arms_pivot.position = PIVOT_BASE_POS
	_arms_pivot.rotation_degrees = PIVOT_BASE_ROT
	viewmodel.add_child(_arms_pivot)

	_arms = ARMS_SCENE.instantiate()
	_arms.name = "FpsArms"
	_arms.scale = Vector3.ONE * ARMS_SCALE
	_arms.position = -ARMS_CENTROID * ARMS_SCALE
	_arms_pivot.add_child(_arms)
	_apply_arm_material(_arms)


func _apply_arm_material(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = _arm_material()
	for child in node.get_children():
		_apply_arm_material(child)


func _arm_material() -> ShaderMaterial:
	# Robe sleeve near the elbow blending to skin at the hand, keyed off local Z.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
uniform vec3 skin : source_color = vec3(0.55, 0.40, 0.28);
uniform vec3 sleeve : source_color = vec3(0.10, 0.09, 0.16);
uniform vec3 cuff : source_color = vec3(0.52, 0.40, 0.16);
varying float zlocal;
void vertex() { zlocal = VERTEX.z; }
void fragment() {
	ROUGHNESS = 0.92;
	float hand = smoothstep(-1.0, 2.5, zlocal);
	vec3 c = mix(sleeve, skin, hand);
	float cuff_band = smoothstep(1.0, 1.6, zlocal) * (1.0 - smoothstep(1.9, 2.5, zlocal));
	c = mix(c, cuff, cuff_band);
	ALBEDO = c;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_motion_count += 1
		if _motion_count <= 3 or _motion_count % 120 == 0:
			_log("motion #%d relative=%s mouse_mode=%d" % [
				_motion_count, str(event.relative), Input.mouse_mode])
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * mouse_sensitivity)
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clamp(head.rotation.x, -PI * 0.48, PI * 0.48)
		else:
			# Motion means the pointer is over the window: capture can succeed now.
			_try_capture("motion")

	if event.is_action_pressed("ui_cancel"):
		_log("ESC pressed: releasing mouse")
		_want_capture = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		_log("mouse button %d pressed (mouse_mode=%d)" % [event.button_index, Input.mouse_mode])
		_want_capture = true
		_try_capture("click")


func _physics_process(delta: float) -> void:
	if LOOK_DEBUG:
		_heartbeat -= delta
		if _heartbeat <= 0.0:
			_heartbeat = 2.0
			_log("heartbeat: mouse_mode=%d want=%s focused=%s motions=%d rot_y=%.3f" % [
				Input.mouse_mode, str(_want_capture), str(get_window().has_focus()),
				_motion_count, rotation.y])

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var target_velocity := direction * move_speed

	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

	move_and_slide()
	_update_viewmodel(delta, input_dir.length())


func _update_viewmodel(delta: float, input_amount: float) -> void:
	var t := Time.get_ticks_msec() * 0.001

	# Walk bob/sway of the whole viewmodel.
	var bob := sin(t * 7.0) * 0.012 * input_amount
	var sway := cos(t * 3.5) * 0.006 * input_amount
	viewmodel.position.y = lerp(viewmodel.position.y, _viewmodel_base_y + bob, 8.0 * delta)
	viewmodel.position.x = lerp(viewmodel.position.x, sway, 6.0 * delta)

	if not _arms_pivot:
		return

	# Idle breathing + gentle drift so the arms feel alive when standing still.
	var breathe := sin(t * 1.3) * 0.01
	var drift_x := sin(t * 0.6) * 0.006
	var idle_pitch := sin(t * 1.1) * 1.3
	var idle_yaw := cos(t * 0.7) * 1.6
	var idle_roll := sin(t * 0.9) * 2.0

	# A slow recurring gesture: a small, eased hand lift/tilt every ~9 s.
	var g := 0.0
	var phase := fmod(t, 9.0)
	if phase < 1.5:
		g = sin(phase / 1.5 * PI)

	_arms_pivot.position = PIVOT_BASE_POS + Vector3(drift_x, breathe + g * 0.035, 0.0)
	_arms_pivot.rotation_degrees = PIVOT_BASE_ROT + Vector3(idle_pitch - g * 6.0, idle_yaw, idle_roll + g * 9.0)
