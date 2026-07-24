class_name VillagerHouse
extends Node3D

@onready var entry_door: Door = $EntryDoor


func _ready() -> void:
	var door_hinge := find_child("house_entry_door_hinge", true, false) as Node3D
	var door_visual := find_child("house_entry_door", true, false) as Node3D
	# push_error, not assert: these must fail loudly in release builds too,
	# where a regenerated glb with renamed nodes would otherwise no-op.
	if door_hinge == null or door_visual == null:
		push_error("VillagerHouse: missing house_entry_door_hinge/house_entry_door in the imported house model.")
	else:
		entry_door.bind_imported_door(door_hinge, door_visual)
