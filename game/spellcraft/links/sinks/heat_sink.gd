class_name HeatSink
extends Node3D

## A patch of ground (or any surface) that a HeatEffect can warm. The effect
## calls set_hot(); this glows an optional indicator and emissive mesh so the
## heat reads in Wizard Sight and in the world, and reports is_hot() for anything
## that cares (a kettle boiling, snow melting, a puzzle gate).

## Optional Node3D shown only while hot (heat-shimmer particles, an ember glow).
@export var indicator_path: NodePath
## Optional MeshInstance3D whose material emission ramps up while hot.
@export var glow_mesh_path: NodePath
@export var hot_emission := Color(1.0, 0.35, 0.08, 1.0)
@export var hot_emission_energy := 1.6

var _hot := false
var _indicator: Node3D
var _glow_material: StandardMaterial3D
var _energy := 0.0
var _tween: Tween


func _ready() -> void:
	_indicator = get_node_or_null(indicator_path) as Node3D
	if _indicator != null:
		_indicator.visible = false
	var glow := get_node_or_null(glow_mesh_path) as MeshInstance3D
	if glow != null:
		_glow_material = StandardMaterial3D.new()
		_glow_material.albedo_color = Color(0.14, 0.13, 0.12)
		_glow_material.emission_enabled = true
		_glow_material.emission = hot_emission
		_glow_material.emission_energy_multiplier = 0.0
		glow.material_override = _glow_material


func set_hot(hot: bool) -> void:
	if _hot == hot:
		return
	_hot = hot
	if _indicator != null:
		_indicator.visible = hot
	if _glow_material != null:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_method(_apply_energy, _energy,
			hot_emission_energy if hot else 0.0, 0.5)


func is_hot() -> bool:
	return _hot


func _apply_energy(value: float) -> void:
	_energy = value
	if _glow_material != null:
		_glow_material.emission_energy_multiplier = value
