@tool
class_name PaletteGrade
extends Node
## Applies a color-correction LUT to the tower's Environment and cycles
## through the palette candidates with F7 (last slot = ungraded) so the
## grades can be A/B'd against the raw render in-game.

@export var luts: Array[Texture3D] = []
@export var lut_names: PackedStringArray = []
@export var active_index: int = 0:
	set(value):
		active_index = value
		_apply()
@export var world_environment_path: NodePath = ^"../WorldEnvironment"


func _ready() -> void:
	_apply()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F7:
		active_index = (active_index + 1) % (luts.size() + 1)
		var label := "ungraded" if active_index == luts.size() else _name_for(active_index)
		print("PaletteGrade: ", label)


func _apply() -> void:
	var world_env := get_node_or_null(world_environment_path) as WorldEnvironment
	if world_env == null or world_env.environment == null:
		return
	if active_index >= 0 and active_index < luts.size():
		world_env.environment.adjustment_color_correction = luts[active_index]
	else:
		world_env.environment.adjustment_color_correction = null


func _name_for(index: int) -> String:
	if index < lut_names.size():
		return lut_names[index]
	var lut := luts[index]
	return lut.resource_path.get_file() if lut else str(index)
