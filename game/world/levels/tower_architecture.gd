class_name TowerArchitecture
extends Node3D

@onready var basement_respawn: Marker3D = $BasementRespawn
@onready var _hatch_blocker: CollisionShape3D = $SecretHatchBlocker/CollisionShape3D
@onready var entry_door: Door = $EntryDoor

var _basement_is_revealed := false
var _closed_hatch: MeshInstance3D
var _open_hatch: MeshInstance3D


func _ready() -> void:
	_closed_hatch = find_child("secret_hatch_closed", true, false) as MeshInstance3D
	_open_hatch = find_child("secret_hatch_open", true, false) as MeshInstance3D
	var door_hinge := find_child("warded_entry_door_hinge", true, false) as Node3D
	var door_visual := find_child("warded_entry_door", true, false) as Node3D
	# push_error, not assert: these must fail loudly in release builds too,
	# where a regenerated glb with renamed nodes would otherwise no-op.
	if _closed_hatch == null or _open_hatch == null:
		push_error("TowerArchitecture: missing secret_hatch_closed/secret_hatch_open meshes in the imported tower model.")
	if door_hinge == null or door_visual == null:
		push_error("TowerArchitecture: missing warded_entry_door_hinge/warded_entry_door in the imported tower model.")
	else:
		entry_door.bind_imported_door(door_hinge, door_visual)
	_apply_basement_state()


func reveal_basement() -> void:
	if _basement_is_revealed:
		return
	_basement_is_revealed = true
	_apply_basement_state()


func is_basement_revealed() -> bool:
	return _basement_is_revealed


func _apply_basement_state() -> void:
	if _closed_hatch != null:
		_closed_hatch.visible = not _basement_is_revealed
	if _open_hatch != null:
		_open_hatch.visible = _basement_is_revealed
	if _hatch_blocker != null:
		_hatch_blocker.set_deferred(&"disabled", _basement_is_revealed)
