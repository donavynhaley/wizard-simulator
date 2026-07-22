class_name TowerArchitecture
extends Node3D

signal basement_revealed

@onready var basement_respawn: Marker3D = $BasementRespawn
@onready var _hatch_blocker: CollisionShape3D = $SecretHatchBlocker/CollisionShape3D
@onready var entry_door: TowerDoor = $EntryDoor

var _basement_is_revealed := false
var _closed_hatch: MeshInstance3D
var _open_hatch: MeshInstance3D


func _ready() -> void:
	_closed_hatch = find_child("secret_hatch_closed", true, false) as MeshInstance3D
	_open_hatch = find_child("secret_hatch_open", true, false) as MeshInstance3D
	var door_hinge := find_child("warded_entry_door_hinge", true, false) as Node3D
	var door_visual := find_child("warded_entry_door", true, false) as Node3D
	assert(_closed_hatch != null, "Tower architecture requires a closed secret hatch mesh.")
	assert(_open_hatch != null, "Tower architecture requires an open secret hatch mesh.")
	assert(door_hinge != null, "Tower architecture requires an authored entrance hinge.")
	assert(door_visual != null, "Tower architecture requires an authored entrance door.")
	entry_door.bind_imported_door(door_hinge, door_visual)
	_apply_basement_state()


func reveal_basement() -> void:
	if _basement_is_revealed:
		return
	_basement_is_revealed = true
	_apply_basement_state()
	basement_revealed.emit()


func is_basement_revealed() -> bool:
	return _basement_is_revealed


func _apply_basement_state() -> void:
	if _closed_hatch != null:
		_closed_hatch.visible = not _basement_is_revealed
	if _open_hatch != null:
		_open_hatch.visible = _basement_is_revealed
	if _hatch_blocker != null:
		_hatch_blocker.set_deferred(&"disabled", _basement_is_revealed)
