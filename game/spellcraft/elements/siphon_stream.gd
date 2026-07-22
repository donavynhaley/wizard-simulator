class_name SiphonStream
extends Node3D

## The visual of essence being moved: an element-tinted ribbon sagging from
## source to palm with wisps racing along it. Both endpoints are sampled every
## frame so the stream tracks a moving hand (or, reversed, follows the vessel).
## It does not deplete the source - it is purely the look of energy in transit.

const SEGMENTS := 14
const FADE_TIME := 0.2

var _from_point: Callable
var _to_point: Callable
var _color := Color.WHITE
var _duration := 0.0
var _life := 0.0
var _wisp_phase := 0.0
var _sway_phase := 0.0
var _mesh: ImmediateMesh

@onready var _ribbon: MeshInstance3D = $Ribbon
@onready var _wisps: GPUParticles3D = $Wisps


func _ready() -> void:
	# Endpoints are global; pin the node to the world origin so vertices can be
	# authored in global coordinates regardless of where the caller parents it.
	top_level = true
	global_transform = Transform3D.IDENTITY
	_mesh = ImmediateMesh.new()
	_ribbon.mesh = _mesh
	_sway_phase = randf() * TAU


## Both endpoints are Callables returning Vector3 so the ribbon can chase
## whatever moves - the hand mid-walk, or a source visual mid-suck.
func setup(from_point: Callable, to_point: Callable, color: Color, duration: float) -> void:
	_from_point = from_point
	_to_point = to_point
	_duration = maxf(duration, 0.05)
	set_color(color)


func set_color(color: Color) -> void:
	_color = color
	var mat := _wisps.process_material as ParticleProcessMaterial
	if mat != null:
		# Push past 1.0 so the wisps bloom against the scene glow.
		mat.color = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 1.0)


func _process(delta: float) -> void:
	if _from_point.is_null() or _to_point.is_null():
		return
	_life += delta
	if _life > _duration + FADE_TIME + 0.05:
		queue_free()
		return
	var fade := clampf(1.0 - (_life - _duration) / FADE_TIME, 0.0, 1.0)
	_wisps.emitting = _life <= _duration
	var from_p: Vector3 = _from_point.call()
	var to_p: Vector3 = _to_point.call()
	var span := to_p - from_p
	if span.length() < 0.03:
		_mesh.clear_surfaces()
		return
	# Drawn magic arcs; it does not beam. Sag plus a slow sideways wander.
	var side := span.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.001 else Vector3.RIGHT
	var control := (from_p + to_p) * 0.5 \
		+ Vector3.DOWN * clampf(span.length() * 0.18, 0.04, 0.5) \
		+ side * sin(_life * 9.0 + _sway_phase) * span.length() * 0.06
	_rebuild_ribbon(from_p, control, to_p, fade)
	_advance_wisps(delta, from_p, control, to_p)


func _rebuild_ribbon(from_p: Vector3, control: Vector3, to_p: Vector3, fade: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in SEGMENTS + 1:
		var t := float(index) / SEGMENTS
		var point := _bezier(from_p, control, to_p, t)
		var tangent := _bezier(from_p, control, to_p, minf(t + 0.06, 1.0)) - point
		var view := camera.global_position - point
		var across := tangent.cross(view)
		across = across.normalized() if across.length() > 0.001 else Vector3.UP
		# Tapered at both ends, brightest through the middle.
		var bulge := sin(PI * t)
		var half_width := 0.035 * (0.35 + 0.65 * bulge)
		var color := Color(
			_color.r * 1.6, _color.g * 1.6, _color.b * 1.6,
			fade * (0.35 + 0.5 * bulge))
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(point + across * half_width)
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(point - across * half_width)
	_mesh.surface_end()


## The wisp emitter rides the curve toward the destination, accelerating as it
## goes - essence commits harder the closer it gets to where it is wanted.
func _advance_wisps(delta: float, from_p: Vector3, control: Vector3, to_p: Vector3) -> void:
	_wisp_phase += delta * (1.6 + 2.8 * _wisp_phase)
	if _wisp_phase >= 1.0:
		_wisp_phase = fmod(_wisp_phase, 1.0)
	_wisps.global_position = _bezier(from_p, control, to_p, _wisp_phase)
	var ahead := _bezier(from_p, control, to_p, minf(_wisp_phase + 0.08, 1.0))
	if _wisps.global_position.distance_to(ahead) > 0.01:
		_wisps.look_at(ahead, Vector3.UP)


func _bezier(a: Vector3, control: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(control, t).lerp(control.lerp(b, t), t)
