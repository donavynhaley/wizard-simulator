@tool
class_name SketchRibbon
extends MeshInstance3D

## Camera-facing emissive ribbon that visualizes the in-progress rune sketch.
## The look is authored in sketch_ribbon.tscn: the shader material lives on
## material_override, the tip sparks are the TipSparks child, and every knob
## below is an inspector export. Opening the scene in the editor shows preview
## strokes at three fade stages that restyle live as the knobs change.
##
## At runtime it parents under the camera so it rides with the player without
## warping; look is frozen during sketching so it never tilts.

@export var plane_depth := 1.8         ## metres in front of the camera
@export var ribbon_half_width := 0.03  ## metres, at plane_depth
@export var halo_width_multiplier := 4.0  ## soft glow strip width vs the core
@export var halo_alpha := 0.55         ## glow strength at the core edge
@export var base_color := Color(0.75, 0.55, 1.0)
@export var recognized_color := Color(0.24, 0.72, 1.0)
## Corner rounding radius in metres at plane_depth (0 = sharp corners). Strokes
## are resampled to this spacing before smoothing so the rounding is the same
## whether points arrived densely or sparsely. Visual only.
@export_range(0.0, 0.3, 0.005) var corner_rounding := 0.06
@export_range(0, 4) var corner_smoothing_passes := 2  ## Chaikin passes on the resampled line
@export_range(0.0, 1.0, 0.01) var fade_start := 0.6  ## life fraction where fading begins

@export_group("Recognition Flare")
@export var flare_energy := 26.0
@export var flare_attack := 0.1
@export var flare_release := 0.45

var _immediate_mesh: ImmediateMesh
var _material: ShaderMaterial
var _rest_energy := 8.0
var _flare_tween: Tween
var _tip_particles: GPUParticles3D


func _ready() -> void:
	_immediate_mesh = ImmediateMesh.new()
	mesh = _immediate_mesh
	cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF
	_tip_particles = get_node_or_null(^"TipSparks") as GPUParticles3D

	_material = material_override as ShaderMaterial
	if _material != null:
		_rest_energy = float(_material.get_shader_parameter("emission_energy"))


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_rebuild_editor_preview()


## Clears the ribbon and resets the flare. Call on entering and leaving a
## sketch session.
func clear() -> void:
	_immediate_mesh.clear_surfaces()
	if _flare_tween != null and _flare_tween.is_valid():
		_flare_tween.kill()
	if _material != null:
		_material.set_shader_parameter("emission_energy", _rest_energy)
	if _tip_particles != null:
		_tip_particles.emitting = false


## Plays the recognition emission flare. Re-triggerable: each new or overriding
## match flares again. Consumed strokes get the recognized tint per stroke.
func mark_recognized() -> void:
	if _material == null:
		return
	if _flare_tween != null and _flare_tween.is_valid():
		_flare_tween.kill()
	_flare_tween = create_tween()
	_flare_tween.tween_method(_set_energy, _rest_energy, flare_energy, flare_attack)
	_flare_tween.tween_method(_set_energy, flare_energy, _rest_energy, flare_release)


## Moves the spark emitter to the cursor's point on the sketch plane and turns
## it on only while a stroke is being drawn.
func update_tip(
		cursor: Vector2,
		camera: Camera3D,
		viewport_size: Vector2,
		drawing: bool) -> void:
	if _tip_particles == null or camera == null:
		return
	_tip_particles.position = _screen_to_local(cursor, camera, viewport_size)
	_tip_particles.emitting = drawing


## Rebuilds the whole ribbon from the current live strokes. Cheap enough to call
## every frame; that is what animates the age fade and reveals new points. The
## active (still being drawn) stroke stays full-bright regardless of age.
func rebuild(
		strokes: Array[SketchStroke],
		camera: Camera3D,
		viewport_size: Vector2,
		lifetime: float) -> void:
	_immediate_mesh.clear_surfaces()
	if camera == null:
		return
	for stroke in strokes:
		if stroke.points.is_empty():
			continue
		var tint := recognized_color if stroke.consumed else base_color
		var local_points := PackedVector3Array()
		var colors := PackedColorArray()
		for i in stroke.points.size():
			local_points.append(_screen_to_local(stroke.points[i], camera, viewport_size))
			var color := tint
			color.a = _fade_alpha(stroke.point_ages[i], lifetime)
			colors.append(color)
		_add_local_stroke(local_points, colors)


## Hold-then-fade: full brightness for most of the stroke's life, then a fade
## over the final stretch as the expiry warning.
func _fade_alpha(age: float, lifetime: float) -> float:
	var life_fraction := clampf(age / maxf(lifetime, 0.001), 0.0, 1.0)
	if life_fraction <= fade_start:
		return 1.0
	return clampf(1.0 - (life_fraction - fade_start) / maxf(1.0 - fade_start, 0.001), 0.0, 1.0)


## Editor-only: three sample strokes at full, mid-fade, and late-fade alpha so
## the look can be tuned in the inspector without running the game. The shapes
## have hard corners and are sampled as densely as live capture, so the corner
## rounding knob previews faithfully.
func _rebuild_editor_preview() -> void:
	if _immediate_mesh == null:
		return
	_immediate_mesh.clear_surfaces()
	var alphas: Array[float] = [1.0, 0.6, 0.25]
	for row in 3:
		var y := 0.3 - float(row) * 0.28
		var waypoints := PackedVector3Array([
			Vector3(-0.55, y - 0.09, -plane_depth),
			Vector3(-0.3, y + 0.09, -plane_depth),
			Vector3(-0.05, y - 0.09, -plane_depth),
			Vector3(0.2, y + 0.09, -plane_depth),
			Vector3(0.45, y + 0.09, -plane_depth),
			Vector3(0.55, y - 0.05, -plane_depth),
		])
		var points := _densify(waypoints, 0.01)
		var colors := PackedColorArray()
		var color := base_color
		color.a = alphas[row]
		for i in points.size():
			colors.append(color)
		_add_local_stroke(points, colors)


## Editor preview helper: subdivides straight runs into ~live-capture density.
func _densify(waypoints: PackedVector3Array, spacing: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(waypoints.size() - 1):
		var steps := maxi(int(waypoints[i].distance_to(waypoints[i + 1]) / spacing), 1)
		for step in steps:
			out.append(waypoints[i].lerp(waypoints[i + 1], float(step) / float(steps)))
	out.append(waypoints[waypoints.size() - 1])
	return out


const CAP_SEGMENTS := 8


## Builds the halo and core strips for one stroke from camera-local points,
## with round caps at both ends so the ink reads as a round brush.
func _add_local_stroke(source_points: PackedVector3Array, source_colors: PackedColorArray) -> void:
	if source_points.is_empty():
		return
	if source_points.size() == 1:
		# A click without a drag leaves a round dot.
		_add_round_cap(source_points[0], Vector3(1, 0, 0), Vector3(0, 1, 0), source_colors[0], TAU)
		return
	# Colors (carrying the per-point fade alpha) ride through resample and smooth
	# on the same lerps as the positions, so each final vertex keeps the right
	# trail alpha.
	var resampled := _resample_points(source_points, source_colors)
	var smoothed := _smooth_points(resampled[0], resampled[1])
	var local_points: PackedVector3Array = smoothed[0]
	var colors: PackedColorArray = smoothed[1]
	var offsets := PackedVector3Array()
	for i in local_points.size():
		var direction := Vector3.ZERO
		if i < local_points.size() - 1:
			direction = local_points[i + 1] - local_points[i]
		else:
			direction = local_points[i] - local_points[i - 1]
		direction.z = 0.0
		if direction.length() < 0.00001:
			direction = Vector3(1.0, 0.0, 0.0)
		direction = direction.normalized()
		offsets.append(Vector3(-direction.y, direction.x, 0.0))

	# Soft geometric halo: two strips graded from the glow color at the core's
	# edge to fully transparent at the halo edge. Because the glow is mesh
	# alpha, it fades uniformly with the stroke instead of collapsing when HDR
	# bloom drops under its threshold.
	var halo_offset := ribbon_half_width * halo_width_multiplier
	for side: float in [1.0, -1.0]:
		_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in local_points.size():
			var halo_color := colors[i]
			halo_color.a = colors[i].a * halo_alpha
			var halo_edge_color := colors[i]
			halo_edge_color.a = 0.0
			var inner := local_points[i] + offsets[i] * (ribbon_half_width * side)
			var outer := local_points[i] + offsets[i] * (halo_offset * side)
			_immediate_mesh.surface_set_color(halo_color)
			_immediate_mesh.surface_add_vertex(inner)
			_immediate_mesh.surface_set_color(halo_edge_color)
			_immediate_mesh.surface_add_vertex(outer)
		_immediate_mesh.surface_end()

	# Bright core strip.
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in local_points.size():
		var offset := offsets[i] * ribbon_half_width
		_immediate_mesh.surface_set_color(colors[i])
		_immediate_mesh.surface_add_vertex(local_points[i] + offset)
		_immediate_mesh.surface_set_color(colors[i])
		_immediate_mesh.surface_add_vertex(local_points[i] - offset)
	_immediate_mesh.surface_end()

	# Round caps: a semicircle sweeping around the outward side of each end,
	# joined exactly to the strip edges so the brush reads round, not square.
	var point_count := local_points.size()
	var start_outward := (local_points[0] - local_points[1])
	var end_outward := (local_points[point_count - 1] - local_points[point_count - 2])
	_add_round_cap(local_points[0], _flat_normalized(start_outward), offsets[0], colors[0], PI)
	_add_round_cap(
		local_points[point_count - 1],
		_flat_normalized(end_outward),
		offsets[point_count - 1],
		colors[point_count - 1],
		PI)


## Adds a round cap (arc = PI for a stroke end, TAU for a lone dot): a core fan
## plus the same halo gradient the strip carries, wrapped around the tip.
func _add_round_cap(
		center: Vector3,
		outward: Vector3,
		perp: Vector3,
		color: Color,
		arc: float) -> void:
	var halo_color := color
	halo_color.a = color.a * halo_alpha
	var halo_edge_color := color
	halo_edge_color.a = 0.0
	var core_radius := ribbon_half_width
	var halo_radius := ribbon_half_width * halo_width_multiplier
	var segment_count := CAP_SEGMENTS if arc <= PI else CAP_SEGMENTS * 2

	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous := center + perp * core_radius
	for i in range(1, segment_count + 1):
		var theta := arc * float(i) / float(segment_count)
		var direction := perp * cos(theta) + outward * sin(theta)
		var current := center + direction * core_radius
		_immediate_mesh.surface_set_color(color)
		_immediate_mesh.surface_add_vertex(center)
		_immediate_mesh.surface_set_color(color)
		_immediate_mesh.surface_add_vertex(previous)
		_immediate_mesh.surface_set_color(color)
		_immediate_mesh.surface_add_vertex(current)
		previous = current
	_immediate_mesh.surface_end()

	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segment_count + 1:
		var theta := arc * float(i) / float(segment_count)
		var direction := perp * cos(theta) + outward * sin(theta)
		_immediate_mesh.surface_set_color(halo_color)
		_immediate_mesh.surface_add_vertex(center + direction * core_radius)
		_immediate_mesh.surface_set_color(halo_edge_color)
		_immediate_mesh.surface_add_vertex(center + direction * halo_radius)
	_immediate_mesh.surface_end()


func _flat_normalized(direction: Vector3) -> Vector3:
	var flat := Vector3(direction.x, direction.y, 0.0)
	if flat.length() < 0.00001:
		return Vector3(1.0, 0.0, 0.0)
	return flat.normalized()


## Resamples a polyline to uniform corner_rounding spacing. Captured strokes
## arrive with a point every few pixels, and Chaikin can only round within one
## segment's length - on dense input that is invisibly small. Resampling first
## makes the corner radius a real authored distance regardless of how fast or
## slow the stroke was drawn.
## Returns [PackedVector3Array points, PackedColorArray colors]; colors are
## lerped on the same t as positions so the trail alpha survives resampling.
func _resample_points(points: PackedVector3Array, colors: PackedColorArray) -> Array:
	if corner_rounding <= 0.001 or points.size() < 3:
		return [points, colors]
	var out_points := PackedVector3Array()
	var out_colors := PackedColorArray()
	out_points.append(points[0])
	out_colors.append(colors[0])
	var carry := 0.0
	for i in range(1, points.size()):
		var from_point := points[i - 1]
		var to_point := points[i]
		var segment_length := from_point.distance_to(to_point)
		if segment_length <= 0.00001:
			continue
		var travelled := carry
		while travelled + corner_rounding <= segment_length:
			travelled += corner_rounding
			var t := travelled / segment_length
			out_points.append(from_point.lerp(to_point, t))
			out_colors.append(colors[i - 1].lerp(colors[i], t))
		carry = travelled - segment_length
	if out_points.size() < 2 or out_points[out_points.size() - 1].distance_to(
			points[points.size() - 1]) > 0.001:
		out_points.append(points[points.size() - 1])
		out_colors.append(colors[colors.size() - 1])
	return [out_points, out_colors]


## Chaikin corner cutting: each pass replaces every segment pair with points at
## 25%/75%, rounding sharp joints. Colors ride the same lerps. Endpoints are
## preserved; visual only, the recognizer still sees the raw captured strokes.
## Returns [PackedVector3Array points, PackedColorArray colors].
func _smooth_points(points: PackedVector3Array, colors: PackedColorArray) -> Array:
	var current_points := points
	var current_colors := colors
	for pass_index in corner_smoothing_passes:
		if current_points.size() < 3:
			return [current_points, current_colors]
		var out_points := PackedVector3Array()
		var out_colors := PackedColorArray()
		out_points.append(current_points[0])
		out_colors.append(current_colors[0])
		for i in range(current_points.size() - 1):
			out_points.append(current_points[i].lerp(current_points[i + 1], 0.25))
			out_points.append(current_points[i].lerp(current_points[i + 1], 0.75))
			out_colors.append(current_colors[i].lerp(current_colors[i + 1], 0.25))
			out_colors.append(current_colors[i].lerp(current_colors[i + 1], 0.75))
		out_points.append(current_points[current_points.size() - 1])
		out_colors.append(current_colors[current_colors.size() - 1])
		current_points = out_points
		current_colors = out_colors
	return [current_points, current_colors]


## Maps a viewport pixel to a point on the frozen plane in front of the camera,
## in the camera's local space (which is this node's space, since it parents to
## the camera at identity).
func _screen_to_local(cursor: Vector2, camera: Camera3D, viewport_size: Vector2) -> Vector3:
	var ndc := Vector2(
		cursor.x / viewport_size.x * 2.0 - 1.0,
		cursor.y / viewport_size.y * 2.0 - 1.0)
	var half_height := plane_depth * tan(deg_to_rad(camera.fov) * 0.5)
	var half_width := half_height * (viewport_size.x / viewport_size.y)
	return Vector3(ndc.x * half_width, -ndc.y * half_height, -plane_depth)


func _set_energy(value: float) -> void:
	_material.set_shader_parameter("emission_energy", value)
