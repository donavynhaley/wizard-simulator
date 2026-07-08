class_name FountainOfEndlessSpring
extends Node3D

@export var prompt_text := "Cup water from the Endless Spring"
@export var refresh_prompt := "Refresh the water in your hands"
@export var already_holding_prompt := "Hands are full"


func focus_prompt(player: WizardPlayer, _collider: Object) -> String:
	if player == null or player.hands == null:
		return ""
	var hands := player.hands
	if hands.held_item == null:
		return prompt_text
	if hands.held_item is HeldWater:
		return refresh_prompt
	return already_holding_prompt


func interact(player: WizardPlayer, _collider: Object) -> void:
	if player == null or player.hands == null:
		return
	var hands := player.hands
	if hands.held_item != null and not (hands.held_item is HeldWater):
		WizardHud.toast(self, "Set down what you're holding first.")
		return
	if hands.held_item is HeldWater:
		var old_water := hands.held_item
		old_water.queue_free()
		hands.notify_item_gone(old_water)
	var water := HeldWater.new()
	water.name = "Held Water"
	add_child(water)
	hands.pick_up(water)
	WizardHud.toast(self, "Cold spring water gathers in your hands.")
