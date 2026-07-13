class_name WizardBodyRig
extends Node3D

## Coordinates the editor-authored first-person rig with the player's held item.
## The beard supplies the downward-facing body silhouette, so no world-body model
## is needed for this first-person-only character.

@export_node_path("FirstPersonWizardRig") var first_person_rig_path: NodePath = \
	^"../Head/Camera3D/Viewmodel/FirstPersonWizardRig"

@onready var _first_person_rig := get_node_or_null(first_person_rig_path) as FirstPersonWizardRig


func _ready() -> void:
	var hands := get_node_or_null(^"../Head/Camera3D/Viewmodel/HandAnchor") as WizardHands
	if hands != null:
		hands.held_changed.connect(_on_held_changed)
		_on_held_changed(hands.held_item)


func set_active(active: bool) -> void:
	if _first_person_rig != null:
		_first_person_rig.set_active(active)


func get_first_person_rig() -> FirstPersonWizardRig:
	return _first_person_rig


func _on_held_changed(item: Node3D) -> void:
	if _first_person_rig != null:
		_first_person_rig.set_holding_item(item != null)
