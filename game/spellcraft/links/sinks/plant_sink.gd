class_name PlantSink
extends Node3D

## A plant an IrrigateEffect can keep watered. The effect calls set_watered();
## this lerps the plant between a dry and a lush tint and reports is_watered()
## for anything that cares (growth, harvest gating, a case fact).

signal water_changed(watered: bool)

## Optional MeshInstance3D whose albedo lerps from dry to lush.
@export var foliage_mesh_path: NodePath
@export var dry_color := Color(0.42, 0.36, 0.14)
@export var lush_color := Color(0.16, 0.45, 0.13)

var _watered := false
var _foliage_material: StandardMaterial3D
var _tween: Tween


func _ready() -> void:
	var foliage := get_node_or_null(foliage_mesh_path) as MeshInstance3D
	if foliage != null:
		_foliage_material = StandardMaterial3D.new()
		_foliage_material.albedo_color = dry_color
		foliage.material_override = _foliage_material


func set_watered(watered: bool) -> void:
	if _watered == watered:
		return
	_watered = watered
	if _foliage_material != null:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(_foliage_material, "albedo_color",
			lush_color if watered else dry_color, 0.6)
	water_changed.emit(watered)


func is_watered() -> bool:
	return _watered
