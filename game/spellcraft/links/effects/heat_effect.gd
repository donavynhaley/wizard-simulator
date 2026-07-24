class_name HeatEffect
extends LinkEffect

## Binds a fire fount to a HeatSink and keeps it hot while the fount burns.
## Sever the link or starve the fount and the sink cools.
##
## Matching is by type, not by tag: anything carrying a HeatSink component can be
## warmed, and the component is what implements set_hot() - one source of truth,
## no string that can disagree with the object it labels.

const FIRE := preload("res://game/spellcraft/elements/fire.tres")


func can_apply(a: LinkAnchor, b: LinkAnchor) -> bool:
	var source := source_of(a, b)
	if source == null or not FIRE.matches(source.provided_element()):
		return false
	var sink := sink_of(a, b)
	return sink != null and sink.target() is HeatSink


func set_active(link: MagicalLink, active: bool) -> void:
	var patch := _get_sink(link)
	if patch != null:
		patch.set_hot(active)


func effect_name() -> String:
	return "Warmth"


func describe(_link: MagicalLink) -> String:
	return "Warmth drawn from fire; the ground stays hot while the fount burns."


func _get_sink(link: MagicalLink) -> HeatSink:
	var sink := link.sink_anchor()
	if sink == null:
		return null
	return sink.target() as HeatSink
