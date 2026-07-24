class_name PlantSink
extends Node3D

## A plant (or any growing thing) an IrrigateEffect can water. The effect calls
## set_watered(); this shows an optional indicator and tweens foliage from dry to
## green, and reports is_watered() for anything that cares (a bloom opening, a
## vine bridging a gap, a puzzle gate).
##
## Attaching this component is what makes a thing waterable - the IrrigateEffect
## matches on the type, so there is no tag to keep in sync with reality.

## Optional Node3D shown only while watered (dripping motes, a bloom).
@export var indicator_path: NodePath
## Optional MeshInstance3D whose albedo tweens between the dry and green colours.
@export var foliage_mesh_path: NodePath
@export var dry_color := Color(0.29, 0.24, 0.11)
@export var green_color := Color(0.16, 0.42, 0.13)

var _watered := false
var _indicator: Node3D
var _foliage_material: StandardMaterial3D
var _blend := 0.0
var _tween: Tween


func _ready() -> void:
	_indicator = get_node_or_null(indicator_path) as Node3D
	if _indicator != null:
		_indicator.visible = false
	var foliage := get_node_or_null(foliage_mesh_path) as MeshInstance3D
	if foliage != null:
		_foliage_material = StandardMaterial3D.new()
		_foliage_material.albedo_color = dry_color
		foliage.material_override = _foliage_material


func set_watered(watered: bool) -> void:
	if _watered == watered:
		return
	_watered = watered
	if _indicator != null:
		_indicator.visible = watered
	if _foliage_material != null:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_method(_apply_blend, _blend, 1.0 if watered else 0.0, 0.8)


func is_watered() -> bool:
	return _watered


func _apply_blend(value: float) -> void:
	_blend = value
	if _foliage_material != null:
		_foliage_material.albedo_color = dry_color.lerp(green_color, value)
