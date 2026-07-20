class_name ElementSource
extends Node3D

## A world source the player can siphon an element from while sketching (a flame
## for fire, water for water, ...). Registered in the "element_source" group so
## the caster can project every source to screen and test it against the cursor.

## The group ("tag") every siphonable source joins, so the caster finds them all.
const GROUP := &"element_source"

@export var element: Element


func _ready() -> void:
	add_to_group(GROUP)


## World point the siphon streams from (this node's position by default).
func siphon_point() -> Vector3:
	return global_position
