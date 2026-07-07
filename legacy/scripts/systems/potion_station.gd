class_name PotionStation
extends Node3D

@export var known_effects: Array[String] = ["healing", "warmth", "revealing", "calming"]
@export var known_bases: Array[String] = ["water", "vinegar", "mushroom broth"]
@export var known_catalysts: Array[String] = ["moon salt", "grave mint", "ember dust"]

var last_potion: Dictionary = {}


func brew_potion(effect: String, base: String, catalyst: String) -> Dictionary:
	if not known_effects.has(effect):
		return _failed_potion("unknown effect")
	if not known_bases.has(base):
		return _failed_potion("bad base")
	if not known_catalysts.has(catalyst):
		return _failed_potion("bad catalyst")

	var volatility := 0.18
	if catalyst == "ember dust":
		volatility += 0.22
	if base == "mushroom broth":
		volatility += 0.12

	last_potion = {
		"name": "%s potion" % effect.capitalize(),
		"effect": effect,
		"base": base,
		"catalyst": catalyst,
		"volatility": volatility,
		"valid": true
	}
	return last_potion


func _failed_potion(reason: String) -> Dictionary:
	last_potion = {
		"name": "Ruined sludge",
		"reason": reason,
		"volatility": 1.0,
		"valid": false
	}
	return last_potion
