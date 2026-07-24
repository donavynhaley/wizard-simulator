class_name PracticeSlate
extends StaticBody3D

## A dark slate the wizard traces against to teach the tower his own hand.
## Interacting cycles the verb the slate listens for; while one is chosen, any
## decisive trace of that verb is kept as a personal exemplar (the recognizer
## keeps every exemplar per verb and the best match wins, so the canon glyph
## still works - the slate only ADDS leniency for this wizard's handwriting).
## Diegetic calibration: the amnesiac relearns his handwriting, and the tower
## relearns it with him.

var _target_index := -1
var _casting: CastingController


func focus_prompt(_player: WizardPlayer, _collider: Object) -> String:
	if _target_index < 0:
		return "Practice your hand at the slate"
	return "The slate awaits %s (next verb)" % RuneGlyphs.display_name(_current_verb())


func interact(player: WizardPlayer, _collider: Object) -> void:
	if player == null or player.casting == null:
		return
	if _casting == null:
		_casting = player.casting
		_casting.practice_recorded.connect(_on_practice_recorded)
	_target_index += 1
	if _target_index >= RuneGlyphs.VERBS.size():
		_target_index = -1
		_casting.practice_verb = &""
		WizardHud.toast(self, "The slate rests")
		return
	var verb := _current_verb()
	_casting.practice_verb = verb
	WizardHud.toast(self, "Trace %s for the slate. %s" % [
		RuneGlyphs.display_name(verb), RuneGlyphs.drawing_hint(verb)])


func _current_verb() -> StringName:
	return RuneGlyphs.VERBS[_target_index]


func _on_practice_recorded(id: StringName) -> void:
	WizardHud.toast(self, "The tower learns your %s" % RuneGlyphs.display_name(id))


func _exit_tree() -> void:
	# Never leave a dangling practice target on the controller.
	if _casting != null and is_instance_valid(_casting) \
			and _casting.practice_verb != &"":
		_casting.practice_verb = &""
