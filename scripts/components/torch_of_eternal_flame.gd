class_name TorchOfEternalFlame
extends Node3D

@export var prompt_text := "Gather eternal flame"
@export var refresh_prompt := "Refresh the flame in your hands"
@export var already_holding_prompt := "Hands are full"
@export var held_fire_scene: PackedScene = preload("res://scenes/artifacts/held_fire.tscn")


func focus_prompt(player: WizardPlayer, _collider: Object) -> String:
	if player == null or player.hands == null:
		return ""
	var hands := player.hands
	if hands.held_item == null:
		return prompt_text
	if hands.held_item is HeldFire:
		return refresh_prompt
	return already_holding_prompt


func interact(player: WizardPlayer, _collider: Object) -> void:
	if player == null or player.hands == null:
		return
	var hands := player.hands
	if hands.held_item != null and not (hands.held_item is HeldFire):
		WizardHud.toast(self, "Set down what you're holding first.")
		return
	if hands.held_item is HeldFire:
		var old_fire := hands.held_item as HeldFire
		old_fire.queue_free()
		hands.notify_item_gone(old_fire)
	var fire := held_fire_scene.instantiate() as HeldFire
	if fire == null:
		push_error("TorchOfEternalFlame requires a HeldFire scene.")
		return
	fire.name = "Held Fire"
	add_child(fire)
	hands.pick_up(fire)
	WizardHud.toast(self, "Eternal flame coils into your hands.")
