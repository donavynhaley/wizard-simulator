extends Node3D

@export var item: Item = null
@export var prompt_text = "Place item"

func focus_prompt(player: WizardPlayer, _collider: Object) -> String:
	if player.hands.held_item == null and item == null:
		return ""
	if player.hands.held_item == null and item != null:
		return "pick up item"
	return prompt_text

func interact(player: WizardPlayer, _collider: Object) -> void:
	var held_item := player.hands.held_item
	if held_item == null and item != null:
		player.hands.pick_up(item)
		item = null

	if held_item is not Item:
		return
	item = held_item
	player.hands.release_item(held_item)
	held_item.reparent(self)
	held_item.position = Vector3.ZERO
	held_item.rotation = Vector3.ZERO
