@tool
class_name DayNightCycle
extends Node

@export var day_length_minutes: float = 24.0
@export_range(0.0, 24.0, 0.01) var start_hour: float = 9.0
@export var auto_start: bool = true
@export var sun_path: NodePath
@export var moon_path: NodePath
@export var world_environment_path: NodePath

@export_group("Sun")
@export var sun_energy_day: float = 2.2
@export var sun_energy_night: float = 0.02
@export var sun_color_day: Color = Color(1.0, 0.93, 0.78)
@export var sun_color_sunset: Color = Color(1.0, 0.48, 0.22)
@export var sun_color_night: Color = Color(0.25, 0.32, 0.55)

@export_group("Moon")
@export var moon_energy_night: float = 0.42
@export var moon_energy_day: float = 0.0
@export var moon_color: Color = Color(0.35, 0.48, 0.95)

@export_group("Sky")
@export var day_sky_top: Color = Color(0.24, 0.57, 1.0)
@export var day_sky_horizon: Color = Color(0.69, 0.87, 1.0)
@export var sunset_sky_top: Color = Color(0.55, 0.22, 0.52)
@export var sunset_sky_horizon: Color = Color(1.0, 0.55, 0.24)
@export var night_sky_top: Color = Color(0.015, 0.025, 0.07)
@export var night_sky_horizon: Color = Color(0.07, 0.08, 0.16)

@export_group("Ambient")
@export var ambient_energy_day: float = 0.85
@export var ambient_energy_night: float = 0.08
@export var ambient_color_day: Color = Color(0.76, 0.86, 1.0)
@export var ambient_color_night: Color = Color(0.12, 0.15, 0.28)

var time_of_day: float = 0.0
var running := true

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _environment: Environment
var _sky_material: ProceduralSkyMaterial


func _ready() -> void:
	running = auto_start
	time_of_day = start_hour
	_sun = _find_or_create_sun()
	_moon = _find_or_create_moon()
	_environment = _find_environment()
	_sky_material = _find_sky_material(_environment)
	_apply_time()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		time_of_day = start_hour
		_apply_time()
		return

	if not running:
		return
	var day_seconds := maxf(1.0, day_length_minutes * 60.0)
	time_of_day = fposmod(time_of_day + delta / day_seconds * 24.0, 24.0)
	_apply_time()


func _find_or_create_sun() -> DirectionalLight3D:
	var existing := get_node_or_null(sun_path) as DirectionalLight3D
	if existing:
		return existing

	existing = get_parent().get_node_or_null("Sun") as DirectionalLight3D
	if existing:
		return existing

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	get_parent().add_child(sun)
	sun.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else null
	return sun


func _find_or_create_moon() -> DirectionalLight3D:
	var existing := get_node_or_null(moon_path) as DirectionalLight3D
	if existing:
		return existing

	existing = get_parent().get_node_or_null("Moon") as DirectionalLight3D
	if existing:
		return existing

	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = moon_color
	moon.shadow_enabled = false
	get_parent().add_child(moon)
	moon.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else null
	return moon


func _find_environment() -> Environment:
	var world_env := get_node_or_null(world_environment_path) as WorldEnvironment
	if world_env == null:
		world_env = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env:
		return world_env.environment
	return null


func _find_sky_material(environment: Environment) -> ProceduralSkyMaterial:
	if environment == null or environment.sky == null:
		return null
	return environment.sky.sky_material as ProceduralSkyMaterial


func _apply_time() -> void:
	if _sun == null:
		return

	var day_amount := _day_amount()
	var sunset_amount := _sunset_amount()
	var night_amount := 1.0 - day_amount
	var sun_dir := _celestial_direction(time_of_day)
	var moon_dir := -sun_dir

	_point_light(_sun, sun_dir)
	_sun.light_energy = lerpf(sun_energy_night, sun_energy_day, day_amount)
	_sun.light_color = sun_color_night.lerp(sun_color_day, day_amount).lerp(
		sun_color_sunset, sunset_amount)

	if _moon:
		_point_light(_moon, moon_dir)
		_moon.light_energy = lerpf(moon_energy_day, moon_energy_night, night_amount)
		_moon.light_color = moon_color

	if _environment:
		_environment.ambient_light_energy = lerpf(ambient_energy_night, ambient_energy_day, day_amount) \
			+ night_amount * 0.08
		_environment.ambient_light_color = ambient_color_night.lerp(ambient_color_day, day_amount)

	if _sky_material:
		var sky_top := night_sky_top.lerp(day_sky_top, day_amount).lerp(sunset_sky_top, sunset_amount)
		var sky_horizon := night_sky_horizon.lerp(day_sky_horizon, day_amount).lerp(
			sunset_sky_horizon, sunset_amount)
		_sky_material.sky_top_color = sky_top
		_sky_material.sky_horizon_color = sky_horizon
		_sky_material.sky_energy_multiplier = lerpf(0.08, 1.1, day_amount)
		_sky_material.sun_angle_max = lerpf(12.0, 32.0, maxf(day_amount, sunset_amount))


func _celestial_direction(hour: float) -> Vector3:
	var orbit := (hour - 6.0) / 24.0 * TAU
	var horizon_arc := cos(orbit)
	var height := sin(orbit)
	return Vector3(horizon_arc, height, 0.35).normalized()


func _point_light(light: DirectionalLight3D, sky_direction: Vector3) -> void:
	var target := -sky_direction
	if absf(target.dot(Vector3.UP)) > 0.98:
		light.look_at(target, Vector3.FORWARD)
	else:
		light.look_at(target, Vector3.UP)


func _day_amount() -> float:
	var sunrise := smoothstep(5.0, 7.0, time_of_day)
	var sunset := 1.0 - smoothstep(18.0, 20.0, time_of_day)
	return clampf(minf(sunrise, sunset), 0.0, 1.0)


func _sunset_amount() -> float:
	var dawn := smoothstep(5.0, 6.5, time_of_day) * (1.0 - smoothstep(6.5, 8.0, time_of_day))
	var dusk := smoothstep(17.0, 18.8, time_of_day) * (1.0 - smoothstep(18.8, 20.5, time_of_day))
	return clampf(maxf(dawn, dusk), 0.0, 1.0)
