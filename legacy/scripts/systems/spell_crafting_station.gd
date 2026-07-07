class_name SpellCraftingStation
extends Node3D

@export var unlocked_intents: Array[String] = ["bind", "cleanse", "reveal", "mend"]
@export var unlocked_forms: Array[String] = ["sigil", "charm", "ray"]
@export var unlocked_targets: Array[String] = ["object", "room", "spirit"]
@export var unlocked_modifiers: Array[String] = ["gentle", "unstable"]

var last_spell: Dictionary = {}


func craft_spell(intent: String, form: String, target: String, modifier: String) -> Dictionary:
	if not unlocked_intents.has(intent):
		return _failed_spell("unknown intent")
	if not unlocked_forms.has(form):
		return _failed_spell("unknown form")
	if not unlocked_targets.has(target):
		return _failed_spell("unknown target")
	if not unlocked_modifiers.has(modifier):
		return _failed_spell("unknown modifier")

	last_spell = {
		"name": "%s %s %s" % [modifier.capitalize(), intent.capitalize(), target.capitalize()],
		"intent": intent,
		"form": form,
		"target": target,
		"modifier": modifier,
		"instability": 0.35 if modifier == "unstable" else 0.08,
		"valid": true
	}
	return last_spell


func _failed_spell(reason: String) -> Dictionary:
	last_spell = {
		"name": "Misread Spell",
		"reason": reason,
		"instability": 1.0,
		"valid": false
	}
	return last_spell
