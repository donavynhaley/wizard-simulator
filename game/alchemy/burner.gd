class_name Burner
extends Node3D

@export var flask_placement: Node3D = null
@export var fire_placement: Node3D = null
var placed_flask: Flask = null
var placed_fire: HeldFire = null
var is_burner_on: bool = false

# Intended burner flow (custody rework will reimplement placement):
# place a flask on the burner, place eternal flame beneath it, the flask
# cooks; when the flame is off the flask can be added or removed.
func _try_cook_placed_flask() -> void:
	if placed_fire == null or placed_flask == null:
		return
	if placed_flask.get_flask_item() == null:
		return
	if placed_flask.is_cooked:
		return
	placed_flask.cook()
	WizardHud.toast(self, "The flask begins to cook over eternal flame.")
