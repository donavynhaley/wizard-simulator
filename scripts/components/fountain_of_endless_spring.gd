class_name FountainOfEndlessSpring
extends Node3D

const HELD_WATER_SCRIPT := preload("res://scripts/props/held_water.gd")

@export var prompt_text := "Cup water from the Endless Spring"
@export var already_holding_prompt := "Hands are full"


func focus_prompt(player: Node3D, _collider: Object) -> String:
	var hands := _hands_for(player)
	if hands == null:
		return ""
	if hands.held_item == null:
		return prompt_text
	if _is_held_water(hands.held_item):
		return "Refresh the water in your hands"
	return already_holding_prompt


func interact(player: Node3D, _collider: Object) -> void:
	var hands := _hands_for(player)
	if hands == null:
		return
	if hands.held_item != null and not _is_held_water(hands.held_item):
		_announce("Set down what you're holding first.")
		return
	if _is_held_water(hands.held_item):
		var old_water: Node = hands.held_item
		old_water.queue_free()
		hands.notify_item_gone(old_water)
	var water := HELD_WATER_SCRIPT.new()
	water.name = "Held Water"
	add_child(water)
	hands.pick_up(water)
	_announce("Cold spring water gathers in your hands.")


func _hands_for(player: Node3D) -> Node:
	if player == null:
		return null
	var hands := player.get_node_or_null("%HandAnchor")
	if hands == null or not hands.has_method("pick_up"):
		return null
	return hands


func _is_held_water(item: Node) -> bool:
	return item != null and item.get_script() == HELD_WATER_SCRIPT


func _announce(text: String) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	var hud := tree.get_first_node_in_group("wizard_hud")
	if hud and hud.has_method("show_toast"):
		hud.call("show_toast", text)
