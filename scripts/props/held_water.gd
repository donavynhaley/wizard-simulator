class_name HeldWater
extends Node3D

@export var held_position: Vector3 = Vector3(-0.045, 0.03, -0.085)
@export var held_rotation: Vector3 = Vector3(-0.48, 0.18, -0.22)
@export var held_scale: Vector3 = Vector3.ONE

const DROPLET_COUNT := 5
const HOLDING_WATER_SOUND := preload("res://assets/sounds/holding_water.wav")

var _is_held := false
var _age := 0.0
var _droplets: Array[Node3D] = []
var _glints: Array[Node3D] = []
var _water_audio: AudioStreamPlayer
var _audio_tween: Tween


func _ready() -> void:
	_build_visual()
	_build_audio()


func _process(delta: float) -> void:
	_age += delta
	_update_droplets()
	_update_glints()


func get_held_pose() -> Dictionary:
	return {
		"position": held_position,
		"rotation": held_rotation,
		"scale": held_scale,
	}


func get_display_name() -> String:
	return "Spring water"


func set_held(value: bool) -> void:
	_is_held = value
	if _is_held:
		_start_holding_audio()
	else:
		_stop_holding_audio()
		queue_free()


func _build_visual() -> void:
	var water_material := _water_material()
	_add_water_blob("CoreBlob", Vector3(0.0, 0.025, 0.0), Vector3(0.92, 0.82, 0.92), 0.18, water_material)
	_add_water_blob("LeftBlob", Vector3(-0.062, 0.01, 0.03), Vector3(0.6, 0.56, 0.58), 0.15, water_material)
	_add_water_blob("RightBlob", Vector3(0.065, 0.015, -0.035), Vector3(0.58, 0.6, 0.62), 0.145, water_material)

	for i in DROPLET_COUNT:
		_add_droplet(i)

	_add_glint("FrontGlint", Vector3(0.075, 0.052, -0.055), 0.048)
	_add_glint("SideGlint", Vector3(-0.07, 0.044, 0.045), 0.032)


func _build_audio() -> void:
	_water_audio = AudioStreamPlayer.new()
	_water_audio.name = "HoldingWaterAudio"
	var stream := HOLDING_WATER_SOUND.duplicate()
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_water_audio.stream = stream
	_water_audio.volume_db = 0.0
	add_child(_water_audio)


func _add_water_blob(
		node_name: String,
		local_position: Vector3,
		local_scale: Vector3,
		radius: float,
		material: ShaderMaterial) -> void:
	var blob := MeshInstance3D.new()
	blob.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	blob.mesh = mesh
	blob.position = local_position
	blob.scale = local_scale
	blob.material_override = material
	add_child(blob)


func _add_droplet(index: int) -> void:
	var droplet := MeshInstance3D.new()
	droplet.name = "OrbitingDroplet%d" % index
	var mesh := SphereMesh.new()
	mesh.radius = 0.018 + float(index % 2) * 0.005
	mesh.height = mesh.radius * 1.8
	mesh.radial_segments = 8
	mesh.rings = 4
	droplet.mesh = mesh
	droplet.material_override = _droplet_material()
	add_child(droplet)
	_droplets.append(droplet)


func _add_glint(node_name: String, local_position: Vector3, radius: float) -> void:
	var glint := MeshInstance3D.new()
	glint.name = node_name
	var glint_mesh := SphereMesh.new()
	glint_mesh.radius = radius
	glint_mesh.height = radius * 0.36
	glint_mesh.radial_segments = 6
	glint_mesh.rings = 2
	glint.mesh = glint_mesh
	glint.position = local_position
	glint.material_override = _glint_material()
	add_child(glint)
	_glints.append(glint)


func _water_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.20, 0.70, 1.0, 0.58);
uniform vec3 glow_color : source_color = vec3(0.08, 0.38, 0.58);

void vertex() {
	float ripple_a = sin(TIME * 4.2 + VERTEX.x * 18.0 + VERTEX.z * 7.0);
	float ripple_b = cos(TIME * 3.3 + VERTEX.z * 15.0);
	VERTEX.y += (ripple_a + ripple_b) * 0.006;
	VERTEX.xz += NORMAL.xz * ripple_a * 0.004;
}

void fragment() {
	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.0);
	ALBEDO = mix(water_color.rgb, vec3(0.82, 0.96, 1.0), rim * 0.55);
	ALPHA = water_color.a;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	EMISSION = glow_color * (0.28 + rim * 0.42);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _glint_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 1.0, 1.0, 0.86)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(0.6, 0.95, 1.0)
	material.emission_energy_multiplier = 0.7
	material.roughness = 0.08
	return material


func _droplet_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.86, 1.0, 0.72)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(0.08, 0.42, 0.68)
	material.emission_energy_multiplier = 0.65
	material.roughness = 0.04
	return material


func _update_droplets() -> void:
	for i in _droplets.size():
		var droplet := _droplets[i]
		var phase := _age * (1.25 + float(i) * 0.11) + float(i) * TAU / float(DROPLET_COUNT)
		var orbit_radius := 0.18 + 0.025 * sin(_age * 1.6 + float(i))
		droplet.position = Vector3(
			cos(phase) * orbit_radius,
			0.065 + sin(phase * 1.7) * 0.035,
			sin(phase) * orbit_radius * 0.68
		)
		var pulse := 0.82 + sin(_age * 4.0 + float(i)) * 0.12
		droplet.scale = Vector3.ONE * pulse


func _update_glints() -> void:
	for i in _glints.size():
		var glint := _glints[i]
		var shimmer := 0.82 + sin(_age * 5.2 + float(i) * 1.9) * 0.18
		glint.scale = Vector3.ONE * shimmer


func _start_holding_audio() -> void:
	if _water_audio == null:
		return
	if _audio_tween and _audio_tween.is_valid():
		_audio_tween.kill()
	if not _water_audio.playing:
		_water_audio.play()
	_water_audio.volume_db = 0.0


func _stop_holding_audio() -> void:
	if _water_audio == null:
		return
	if _audio_tween and _audio_tween.is_valid():
		_audio_tween.kill()
	_water_audio.stop()
