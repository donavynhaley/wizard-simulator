class_name Burner
extends Node3D

@export var prompt_text := "Place flask on burner"
@export var fire_prompt := "Place fire on burner"
@export var remove_prompt := "Pick up flask from burner"
@export var full_fire_prompt := "Burner already has eternal flame"
@export var flask_placement: Node3D = null
@export var fire_placement: Node3D = null
var placed_flask: Flask = null
var placed_fire: HeldFire = null
var is_burner_on: bool = false

func focus_prompt(player: WizardPlayer, _collider: Object) -> String:
	if player == null or player.hands == null:
		return ""
	var hands := player.hands
	if hands.held_item is Flask:
		return prompt_text if placed_flask == null else "Burner already has a flask"
	if hands.held_item is HeldFire:
		return fire_prompt if placed_fire == null else full_fire_prompt
	if placed_flask != null:
		return remove_prompt
		
	return prompt_text

# if player has empty hands or incompatible item announce that they need to change that
# if player has compatible item (volumetric flask)
# take item out of hands
# place on burner
# (turn flame on) start cooking item
# item changes to show cooking status
# (turn flame off) item will have cooking status (overheated, underheated, complete)
# When flame is off player can add an item or remove placed item.
func interact(player: WizardPlayer, _collider: Object) -> void:
	if player == null or player.hands == null:
		return
	var hands := player.hands

	if placed_flask == null and hands.held_item is Flask:
		placed_flask = (hands.held_item as Flask)
		hands.release_item(hands.held_item)
		placed_flask.reparent(self)
		placed_flask.set_stationed(true)
		placed_flask.position = flask_placement.position
		placed_flask.rotation = Vector3.ZERO
		_try_cook_placed_flask()
		return
	if placed_fire == null and hands.held_item is HeldFire:
		var held_fire := hands.held_item as HeldFire
		hands.release_item(held_fire)
		placed_fire = held_fire
		placed_fire.reparent(self)
		placed_fire.position = fire_placement.position
		placed_fire.rotation = Vector3.ZERO
		placed_fire.scale = Vector3.ONE
		is_burner_on = true
		_try_cook_placed_flask()
		return
	if hands.held_item is HeldFire:
		WizardHud.toast(self, "The burner already has eternal flame.")
		return
	if placed_flask != null and hands.held_item == null:
		placed_flask.interact(player, _collider)
		placed_flask = null
		return


func _try_cook_placed_flask() -> void:
	if placed_fire == null or placed_flask == null:
		return
	if placed_flask.get_flask_item() == null:
		return
	if placed_flask.is_cooked:
		return
	placed_flask.cook()
	WizardHud.toast(self, "The flask begins to cook over eternal flame.")
