class_name HeldItemSource
extends Node

## Reusable interaction component for world props that place a renewable item
## in the player's hands, such as the Endless Spring and Eternal Flame.

@export var item_scene: PackedScene
@export var accepted_item_script: Script
@export var item_name: String = "Held Item"

@export_group("Prompts")
@export var gather_prompt: String = "Gather item"
@export var refresh_prompt: String = "Refresh held item"
@export var hands_full_prompt: String = "Hands are full"

@export_group("Feedback")
@export var gathered_message: String = "Item gathered."
@export var hands_full_message: String = "Set down what you're holding first."


func focus_prompt(player: WizardPlayer, _collider: Object) -> String:
	var hands := player.hands if player != null else null
	if hands == null:
		return ""
	if hands.held_item == null:
		return gather_prompt
	if _accepts(hands.held_item):
		return refresh_prompt
	return hands_full_prompt


func interact(player: WizardPlayer, _collider: Object) -> void:
	var hands := player.hands if player != null else null
	if hands == null:
		return
	if hands.held_item != null and not _accepts(hands.held_item):
		WizardHud.toast(self, hands_full_message)
		return
	if _accepts(hands.held_item):
		var old_item := hands.held_item
		hands.notify_item_gone(old_item)
		old_item.queue_free()

	var item := _instantiate_item()
	if item == null:
		return
	item.name = item_name
	add_child(item)
	hands.pick_up(item)
	WizardHud.toast(self, gathered_message)


func _accepts(item: Node3D) -> bool:
	return item != null \
		and accepted_item_script != null \
		and item.get_script() == accepted_item_script


func _instantiate_item() -> Node3D:
	if item_scene == null:
		push_error("HeldItemSource requires an item scene.")
		return null
	var item := item_scene.instantiate() as Node3D
	if item == null:
		push_error("HeldItemSource item scene must instantiate a Node3D.")
	return item
